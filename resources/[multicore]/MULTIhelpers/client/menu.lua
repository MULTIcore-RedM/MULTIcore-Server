-- ============================================================
-- MULTIhelpers :: menu (stands in for vorp_menu)
--
--   local MenuData = exports.vorp_menu:GetMenuData()
--   MenuData.Open(type, namespace, name, data, submit, cancel, change, close)
--   MenuData.Close(type, namespace, name)        MenuData.CloseAll(showRadar, soundClose, fireEventClose)
--   MenuData.GetOpened(type, namespace, name)    MenuData.GetOpenedMenus()
--   MenuData.IsOpen(type, namespace, name)       MenuData.ReOpen(type, namespace, name)
--   MenuData.RegisterControls(controls, onPress) MenuData.UnregisterControls()
--
-- The menu object handed to callbacks (and returned by Open):
--   menu.close(showRadar, soundClose, fireEventClose)  menu.refresh()
--   menu.addNewElement(el)  menu.getElementByValue(v)  menu.getElementByIndex(i)
--   menu.setElement(i, field, value)  menu.removeElementByValue(v, all)
--   menu.removeElementByIndex(i, all)  menu.setTitle(t)  menu.setSubtext(t)
--   menu.displayInput(options, onSubmit, onCancel)
--
-- Written from VORP's public docs (docs.vorp-core.com/api-reference/menu)
-- and from how scripts call it. No VORP code is used.
-- ============================================================

local Cfg = Config.Menu

local stack = {}       -- open menus, oldest first; the last one is shown
local positions = {}   -- [namespace..'/'..name] = last selected index (reopen where you left off)
local seq = 0
local radarHiddenByUs = false
local controls = nil   -- { list = {...}, onPress = fn, owner = res }

local MenuData = {}

-- ------------------------------------------------------------ helpers
local function key(m) return tostring(m.namespace) .. '/' .. tostring(m.name) end

local function findMenu(mtype, namespace, name)
    for i = #stack, 1, -1 do
        local m = stack[i]
        if m.type == mtype and m.namespace == namespace and m.name == name then return m, i end
    end
end

local function findById(id)
    for i = #stack, 1, -1 do
        if stack[i].id == id then return stack[i], i end
    end
end

local function top() return stack[#stack] end

local function selectable(el)
    return type(el) == 'table' and not el.isNotSelectable
end

local function clampIndex(m, idx)
    local els = m.data.elements
    local n = #els
    if n == 0 then return 1 end
    idx = math.max(1, math.min(n, math.floor(tonumber(idx) or 1)))
    if selectable(els[idx]) then return idx end
    for i = idx + 1, n do if selectable(els[i]) then return i end end
    for i = idx - 1, 1, -1 do if selectable(els[i]) then return i end end
    return idx
end

local function numberIndexes(m)
    for i, el in ipairs(m.data.elements) do
        if type(el) == 'table' then el.index = i end
    end
end

-- What the page needs to draw a menu.
local function view(m)
    local d = m.data
    numberIndexes(m)
    return {
        id = m.id,
        title = d.title, subtext = d.subtext,
        align = d.align or Cfg.Align,
        elements = d.elements,
        index = m.index,
        itemHeight = d.itemHeight, labelPos = d.labelPos,
        divider = d.divider, fixedHeight = d.fixedHeight,
        maxVisibleItems = tonumber(d.maxVisibleItems) or Cfg.MaxVisibleItems,
        isGrid = d.isGrid,
        confirmButton = d.confirmButton, cancelButton = d.cancelButton,
        lastmenu = d.lastmenu,
        cursor = d.enableCursor == true or Cfg.CursorByDefault,
    }
end

local function syncFocus()
    local m = top()
    if not m then
        Helpers.SetFocus('menu', nil)
        return
    end
    Helpers.SetFocus('menu', {
        keyboard = true,
        cursor = m.data.enableCursor == true or Cfg.CursorByDefault,
        keepInput = Cfg.KeepGameInput,
    })
end

local function show()
    local m = top()
    if m then
        m.dirty = false
        Helpers.Send('menuShow', view(m))
    else
        Helpers.Send('menuHide')
    end
    syncFocus()
end

-- Changes made through the menu object are drawn on the next tick (menu.refresh() draws now).
local function markDirty(m)
    if m.dirty then return end
    m.dirty = true
    SetTimeout(0, function()
        if m.dirty and top() == m then show() end
        m.dirty = false
    end)
end

local function anyHidesRadar()
    for _, m in ipairs(stack) do
        if m.data.hideRadar then return true end
    end
    return false
end

local function updateRadar()
    if anyHidesRadar() and not radarHiddenByUs and not IsRadarHidden() then
        DisplayRadar(false)
        radarHiddenByUs = true
    end
end

-- showRadar == false keeps the radar hidden after the last hiding menu closes
local function restoreRadar(showRadar)
    if radarHiddenByUs and not anyHidesRadar() then
        if showRadar ~= false then DisplayRadar(true) end
        radarHiddenByUs = false
    end
end
-- data passed to submit / change / cancel / close: { current, elements }
local function cbData(m, el)
    return { current = el, elements = m.data.elements }
end

local function run(fn, ...)
    if fn == nil then return end
    local args = table.pack(...)
    CreateThread(function() Helpers.SafeCall(fn, table.unpack(args, 1, args.n)) end)
end

-- ------------------------------------------------------------ the menu object
local closeMenu

local function makePublic(m)
    local pub = {
        type = m.type, namespace = m.namespace, name = m.name,
        data = m.data,
    }

    function pub.close(showRadar, soundClose, fireEventClose)
        closeMenu(m, showRadar, soundClose, fireEventClose)
    end

    function pub.refresh()
        if top() == m then show() end
    end

    function pub.addNewElement(el)
        if type(el) ~= 'table' then return end
        m.data.elements[#m.data.elements + 1] = el
        markDirty(m)
    end

    function pub.getElementByValue(value)
        for i, el in ipairs(m.data.elements) do
            if el.value == value then el.index = i return el end
        end
    end

    function pub.getElementByIndex(index)
        local el = m.data.elements[tonumber(index) or 0]
        if el then el.index = tonumber(index) end
        return el
    end

    function pub.setElement(index, field, newValue)
        local el = m.data.elements[tonumber(index) or 0]
        if not el or field == nil then return end
        el[field] = newValue
        markDirty(m)
    end

    function pub.removeElementByValue(value, all)
        local els = m.data.elements
        for i = #els, 1, -1 do
            if els[i].value == value then
                table.remove(els, i)
                if not all then break end
            end
        end
        m.index = clampIndex(m, m.index)
        markDirty(m)
    end

    function pub.removeElementByIndex(index, all)
        local els = m.data.elements
        index = tonumber(index)
        if not index or not els[index] then return end
        if all then
            -- remove every element with the same value as the one at index
            local v = els[index].value
            for i = #els, 1, -1 do
                if els[i].value == v then table.remove(els, i) end
            end
        else
            table.remove(els, index)
        end
        m.index = clampIndex(m, m.index)
        markDirty(m)
    end

    function pub.setTitle(title)
        m.data.title = title
        markDirty(m)
    end

    function pub.setSubtext(subtext)
        m.data.subtext = subtext
        markDirty(m)
    end

    --- options = { inputType = 'text'|'number'|'password'|'date'|'yesno', header, placeholder,
    ---             description, buttons = { confirm, cancel }, maxLength, pattern, patternMessage }
    --- With callbacks it returns at once; without, it waits and returns the value (nil = cancelled).
    function pub.displayInput(options, onSubmit, onCancel)
        options = type(options) == 'table' and options or {}
        local yesno = options.inputType == 'yesno'
        local spec = {
            kind = yesno and 'yesno' or 'input',
            header = options.header,
            placeholder = options.placeholder,
            description = options.description,
            button = options.buttons and options.buttons.confirm or nil,
            cancelButton = options.buttons and options.buttons.cancel or nil,
            inputType = yesno and 'text' or (options.inputType or 'text'),
            preset = options.pattern,          -- named presets (letters, numbers, ...) or a regex
            title = options.patternMessage,
            maxLength = options.maxLength,
        }
        local p = (onSubmit == nil and onCancel == nil) and promise.new() or nil
        Helpers.OpenDialog(spec, function(result)
            if yesno and result ~= nil then result = true end
            if p then
                p:resolve(result)
            elseif result ~= nil then
                if onSubmit then Helpers.SafeCall(onSubmit, result) end
            else
                if onCancel then Helpers.SafeCall(onCancel) end
            end
        end, m.owner)
        if p then return Citizen.Await(p) end
    end

    return pub
end

-- ------------------------------------------------------------ open / close
closeMenu = function(m, showRadar, soundClose, fireEventClose, noCallbacks)
    local _, i = findById(m.id)
    if not i then return end
    table.remove(stack, i)
    positions[key(m)] = m.index
    restoreRadar(showRadar)
    if soundClose ~= false then Helpers.Sound('close') end
    if not noCallbacks then
        if fireEventClose ~= false then
            TriggerEvent('vorp:menu:closemenu', { type = m.type, namespace = m.namespace, name = m.name, title = m.data.title })
        end
        run(m.closeCb, cbData(m, m.data.elements[m.index]), m.public)
    end
    show()
    Helpers.Debug('menu closed', key(m))
end

function MenuData.Open(mtype, namespace, name, data, submit, cancel, change, close)
    data = type(data) == 'table' and data or {}
    data.elements = type(data.elements) == 'table' and data.elements or {}

    -- the same menu opened again replaces the old one
    local old = findMenu(mtype, namespace, name)
    if old then closeMenu(old, false, false, false, true) end

    seq = seq + 1
    local m = {
        id = seq, type = mtype, namespace = namespace, name = name, data = data,
        submit = submit, cancel = cancel, change = change, closeCb = close,
        owner = GetInvokingResource() or GetCurrentResourceName(),
    }
    m.index = clampIndex(m, data.selected or positions[key(m)] or 1)
    m.public = makePublic(m)
    stack[#stack + 1] = m

    updateRadar()
    if data.soundOpen ~= false then Helpers.Sound('open') end
    show()
    if not data.skipOpenEvent then
        TriggerEvent('vorp:menu:openmenu', { type = mtype, namespace = namespace, name = name, title = data.title })
    end
    Helpers.Debug('menu open', key(m), #data.elements .. ' elements')
    return m.public
end

function MenuData.Close(mtype, namespace, name)
    local m = findMenu(mtype, namespace, name)
    if m then closeMenu(m) end
end

function MenuData.CloseAll(showRadar, soundClose, fireEventClose)
    local list = {}
    for i = #stack, 1, -1 do list[#list + 1] = stack[i] end
    for n, m in ipairs(list) do
        -- one close sound for the lot
        closeMenu(m, showRadar, n == 1 and soundClose ~= false, fireEventClose)
    end
end

function MenuData.GetOpened(mtype, namespace, name)
    local m = findMenu(mtype, namespace, name)
    return m and m.public or nil
end

function MenuData.GetOpenedMenus()
    local out = {}
    for _, m in ipairs(stack) do out[#out + 1] = m.public end
    return out
end

function MenuData.IsOpen(mtype, namespace, name)
    return findMenu(mtype, namespace, name) ~= nil
end

--- Bring an open (covered) menu back to the front. Accepts (type, namespace, name) or a menu object.
function MenuData.ReOpen(mtype, namespace, name)
    if type(mtype) == 'table' then
        mtype, namespace, name = mtype.type, mtype.namespace, mtype.name
    end
    local m, i = findMenu(mtype, namespace, name)
    if not m then return false end
    table.remove(stack, i)
    stack[#stack + 1] = m
    show()
    return true
end

--- Extra keys (KeyboardEvent.key names, 'scrollup', 'scrolldown', 'mousepress') reported to onPress
--- while a menu is open. Calling it again replaces the set.
function MenuData.RegisterControls(list, onPress)
    if type(list) ~= 'table' then return end
    controls = { list = list, onPress = onPress, owner = GetInvokingResource() }
    Helpers.Send('menuControls', list)
end

function MenuData.UnregisterControls()
    controls = nil
    Helpers.Send('menuControls', {})
end

-- ------------------------------------------------------------ page events
local function sliderChange(m, el, d)
    local t = el.type
    if t == 'slider' or t == 'label-slider' then
        el.value = tonumber(d.value) or el.value
    elseif t == 'text-slider' then
        el.textIndex = tonumber(d.textIndex) or el.textIndex
    elseif t == 'desc-slider' then
        local si = tonumber(d.sliderIndex)
        if si and type(el.sliders) == 'table' and el.sliders[si] then
            el.sliderIndex = si
            el.sliders[si].value = tonumber(d.value) or el.sliders[si].value
        end
    elseif t == 'tick-box' then
        el.tickBoxIndex = tonumber(d.tickBoxIndex) or el.tickBoxIndex
    end
end

local function toggleTick(el)
    if el.type == 'tick-box' and type(el.tickBoxes) == 'table' then
        local tb = el.tickBoxes[tonumber(el.tickBoxIndex) or 1]
        if tb then tb.value = tb.value == 'ticked' and 'unticked' or 'ticked' end
        return true
    elseif el.tickBox then
        el.value = el.value == 'ticked' and 'unticked' or 'ticked'
        return true
    end
    return false
end

local function cancelMenu(m)
    Helpers.Sound('back')
    if m.cancel then
        run(m.cancel, cbData(m, m.data.elements[m.index]), m.public)
    else
        closeMenu(m)
    end
end

RegisterNUICallback('menu', function(d, reply)
    reply('ok')
    if type(d) ~= 'table' then return end

    if d.ev == 'control' then
        if controls and controls.onPress and d.name then run(controls.onPress, tostring(d.name)) end
        return
    end

    local m = findById(d.id)
    if not m or top() ~= m then return end
    local els = m.data.elements

    if d.ev == 'select' then
        local idx = clampIndex(m, d.index)
        if idx == m.index then return end
        Helpers.Sound(idx < m.index and 'up' or 'down')
        m.index = idx
        positions[key(m)] = idx
        run(m.change, cbData(m, els[idx]), m.public)

    elseif d.ev == 'slide' then
        local el = els[tonumber(d.index) or 0]
        if not el then return end
        m.index = clampIndex(m, d.index)
        sliderChange(m, el, d)
        Helpers.Sound(d.dir == 'left' and 'left' or 'right')
        run(m.change, cbData(m, el), m.public)

    elseif d.ev == 'submit' then
        local idx = tonumber(d.index) or m.index
        local el = els[idx]
        if not el or el.isDisabled or el.isNotSelectable then return end
        m.index = idx
        if d.tickBoxIndex then el.tickBoxIndex = tonumber(d.tickBoxIndex) end
        if toggleTick(el) then
            markDirty(m)
            run(m.change, cbData(m, el), m.public)
        end
        Helpers.Sound('select')
        run(m.submit, cbData(m, el), m.public)

    elseif d.ev == 'back' then
        if m.data.lastmenu then
            -- VORP style: submit is called with current = 'backup' and trigger = lastmenu
            Helpers.Sound('back')
            run(m.submit, { current = 'backup', trigger = m.data.lastmenu }, m.public)
        else
            cancelMenu(m)
        end

    elseif d.ev == 'cancel' then
        cancelMenu(m)

    elseif d.ev == 'button' then
        if d.which == 'cancel' then
            cancelMenu(m)
        elseif type(m.data.confirmButton) == 'table' then
            Helpers.Sound('select')
            local btn = {}
            for k, v in pairs(m.data.confirmButton) do btn[k] = v end
            btn.isButton = true
            run(m.submit, { current = btn, elements = els, button = 'confirm' }, m.public)
        end
    end
end)

-- A caller stopped: drop its menus and controls without calling back into it.
AddEventHandler('onClientResourceStop', function(res)
    if controls and controls.owner == res then MenuData.UnregisterControls() end
    local changed = false
    for i = #stack, 1, -1 do
        if stack[i].owner == res then
            table.remove(stack, i)
            changed = true
        end
    end
    if changed then
        restoreRadar(true)
        show()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if radarHiddenByUs then DisplayRadar(true) end
end)

-- ------------------------------------------------------------ exports
Helpers.Export('GetMenuData', function() return MenuData end, { 'vorp_menu' })
-- the docs list these next to GetMenuData as core functions, so they answer straight off the export too
Helpers.Export('CloseAll', MenuData.CloseAll, { 'vorp_menu' })
Helpers.Export('RegisterControls', MenuData.RegisterControls, { 'vorp_menu' })
Helpers.Export('UnregisterControls', MenuData.UnregisterControls, { 'vorp_menu' })

Helpers.MenuData = MenuData
