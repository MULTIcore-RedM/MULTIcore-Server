-- ============================================================
-- MULTIhelpers :: feather-menu (v1) stand-in
-- FeatherMenu = exports['feather-menu'].initiate() gives the menu API:
--   FeatherMenu:RegisterMenu(id, config, callbacks) -> menu
--   menu:RegisterPage(id) -> page ; page:RegisterElement(type, data, cb) -> element
--   page:RouteTo(), menu:Open(opts), menu:Close(opts), FeatherMenu:Notify(cfg, cb)
-- Drawn on MULTIhelpers' page by html/feather/feather.js in the MULTI look.
-- Own code, written from the public description of the API. GPL v3.
-- ============================================================

local Feather = {}            -- the API object handed out by initiate()
local menus = {}              -- [menuID] = menu
local openMenu = nil          -- menu on screen
local openPage = nil          -- page on screen
local openOpts = nil          -- options it was opened with
local idSeq = 0
local toasts = {}             -- [toastId] = callback

local function nextId(prefix)
    idSeq = idSeq + 1
    return ('%s-%d'):format(prefix, idSeq)
end

local function playSound(s)
    if type(s) ~= 'table' then return end
    local action, set = s.action or s[1], s.soundset or s[2]
    if action and set then PlaySoundFrontend(tostring(action), tostring(set), true, 0) end
end

local function copy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return nil end
    seen[t] = true
    local out = {}
    for k, v in pairs(t) do
        local tv = type(v)
        -- functions from other scripts arrive as callable tables: leave those out too
        local isRef = tv == 'table' and rawget(v, '__cfx_functionReference') ~= nil
        if tv ~= 'function' and tv ~= 'userdata' and not isRef then out[k] = copy(v, seen) end
    end
    seen[t] = nil
    return out
end

-- ------------------------------------------------------------ what the page gets
local function elementView(el)
    return { id = el.id, type = el.type, slot = el.slot, data = copy(el.data) }
end

local function pageView(page)
    local list = {}
    for i, el in ipairs(page.elements) do list[i] = elementView(el) end
    return { id = page.id, elements = list }
end

local function menuView(menu)
    local c = menu.config or {}
    local keys = {}
    if type(c.keyclicks) == 'table' then
        for k in pairs(c.keyclicks) do keys[#keys + 1] = tostring(k) end
    end
    return {
        id = menu.id,
        top = c.top, left = c.left,
        style = copy(c.style),
        contentslot = copy(c.contentslot), headerslot = copy(c.headerslot), footerslot = copy(c.footerslot),
        draggable = c.draggable == true,
        canclose = c.canclose ~= false,
        keys = keys,
    }
end

local function fire(menu, cbName, eventName, event)
    TriggerEvent(eventName, event)
    local cbs = menu.callbacks
    if type(cbs) == 'table' and cbs[cbName] then Helpers.SafeCall(cbs[cbName], event) end
end

local function routedEvent(menu, page)
    local ids = {}
    for i, el in ipairs(page.elements) do ids[i] = el.id end
    return { menuid = menu.id, pageid = page.id, elements = ids }
end

local function showPage(menu, page)
    openPage = page
    Helpers.Send('featherShow', { menu = menuView(menu), page = pageView(page) })
end

local function isShown(page)
    return openMenu ~= nil and openPage == page
end

local function resendIfShown(page)
    if isShown(page) then showPage(openMenu, page) end
end

-- ------------------------------------------------------------ focus
local function setFocus(opts)
    if not opts then
        Helpers.SetFocus('feather', nil)
        return
    end
    Helpers.SetFocus('feather', {
        keyboard = opts.menuFocus ~= false,
        cursor = opts.cursorFocus ~= false,
        keepInput = opts.allowKeys == true,
    })
end

-- While game keys stay live under the menu, stop the camera, weapons and pause menu.
local function guardThread()
    CreateThread(function()
        while openMenu and openOpts and openOpts.allowKeys == true do
            DisableControlAction(0, 0xA987235F, true)   -- INPUT_LOOK_LR
            DisableControlAction(0, 0xD2047988, true)   -- INPUT_LOOK_UD
            DisableControlAction(0, 0x07CE1E61, true)   -- INPUT_ATTACK
            DisableControlAction(0, 0xF84FA74F, true)   -- INPUT_AIM
            DisableControlAction(0, 0xD82E0BD2, true)   -- INPUT_FRONTEND_PAUSE
            DisableControlAction(0, 0x4CC0E2FE, true)   -- INPUT_FRONTEND_PAUSE_ALTERNATE
            Wait(0)
        end
    end)
end

-- ------------------------------------------------------------ close / open
local function closeMenu(opts)
    local menu = openMenu
    if not menu then return end
    playSound(opts and opts.sound)
    openMenu, openPage, openOpts = nil, nil, nil
    Helpers.Send('featherHide')
    setFocus(nil)
    fire(menu, 'closed', 'FeatherMenu:closed', { menuid = menu.id })
end

local function findPage(menu, ref)
    if type(ref) == 'table' then
        local id = ref.id or ref.pageID
        if id ~= nil and menu.pages[id] then return menu.pages[id] end
    elseif ref ~= nil and menu.pages[ref] then
        return menu.pages[ref]
    end
    return nil
end

local function openMenuWith(menu, opts)
    opts = type(opts) == 'table' and opts or {}
    if openMenu and openMenu ~= menu and opts.overrideMenu == false then return false end
    local page = findPage(menu, opts.startupPage) or menu.pageOrder[1] and menu.pages[menu.pageOrder[1]]
    if not page then
        print(('^1[MULTIhelpers] feather-menu: menu %s has no page to open^7'):format(tostring(menu.id)))
        return false
    end
    if openMenu and openMenu ~= menu then closeMenu() end
    local wasOpen = openMenu == menu
    openMenu, openOpts = menu, opts
    playSound(opts.sound)
    showPage(menu, page)
    setFocus(opts)
    if opts.allowKeys == true then guardThread() end
    if not wasOpen then fire(menu, 'opened', 'FeatherMenu:opened', { menuid = menu.id }) end
    fire(menu, 'topage', 'FeatherMenu:Page:RoutedTo', routedEvent(menu, page))
    return true
end

-- ------------------------------------------------------------ elements
local VALUE_TYPES = {
    input = true, textarea = true, slider = true, arrows = true, toggle = true,
    checkbox = true, dropdown = true, gridslider = true,
}

local function newElement(page, elType, data, cb)
    data = type(data) == 'table' and data or {}
    local el = {
        id = data.id ~= nil and tostring(data.id) or nextId('el'),
        type = tostring(elType or 'textdisplay'),
        slot = data.slot or 'content',
        data = data,
        callback = cb,
        page = page,
    }
    if data.persist == nil then data.persist = true end

    -- starting values the page shows
    if el.type == 'slider' and data.value == nil then data.value = data.start or data.min or 0 end
    if (el.type == 'toggle' or el.type == 'checkbox') and data.value == nil then data.value = data.start == true end
    if el.type == 'arrows' then
        data.persistindex = data.persistindex or tonumber(data.start) or 1
    end
    if el.type == 'dropdown' and data.value == nil then data.value = data.selectedValue end
    if el.type == 'gridslider' and type(data.value) ~= 'table' then data.value = { x = 0, y = 0 } end

    local api = {}
    api.id = el.id
    api.type = el.type
    api.data = data
    function api.update(_, newData)
        if type(newData) ~= 'table' then return end
        for k, v in pairs(newData) do el.data[k] = v end
        if el.type == 'arrows' and newData.start ~= nil and newData.persistindex == nil then
            el.data.persistindex = tonumber(newData.start) or el.data.persistindex
        end
        if newData.slot then el.slot = newData.slot end
        if isShown(el.page) then
            Helpers.Send('featherUpdate', { element = elementView(el) })
        end
    end
    function api.UnRegister()
        local list = el.page.elements
        for i = #list, 1, -1 do
            if list[i] == el then table.remove(list, i) end
        end
        el.page.byId[el.id] = nil
        resendIfShown(el.page)
    end
    el.api = api
    return el
end

-- a click or change from the page
local function elementEvent(el, d)
    local data = el.data
    local value = d.value
    local out = {
        id = el.id, type = el.type, pageID = el.page.id, menuID = el.page.menu.id,
        data = data,
    }
    if el.type == 'arrows' then
        local idx = math.floor(tonumber(d.index) or 1)
        local opts = data.options or {}
        if idx < 1 then idx = 1 end
        if idx > #opts then idx = #opts end
        value = opts[idx]
        out.persistindex = idx
        if data.persist ~= false then data.persistindex = idx end
    elseif el.type == 'pagearrows' then
        value = (d.value == 'back') and 'back' or 'forward'
    elseif el.type == 'slider' then
        value = tonumber(value) or data.value
    elseif el.type == 'toggle' or el.type == 'checkbox' then
        value = value == true
    elseif el.type == 'gridslider' then
        if type(value) == 'table' then value = { x = tonumber(value.x) or 0, y = tonumber(value.y) or 0 } end
    elseif el.type == 'dropdown' then
        -- the page sends the option's place, so numbers stay numbers
        local o = data.options and data.options[math.floor(tonumber(d.index) or 0)]
        if type(o) == 'table' then
            value = o.value ~= nil and o.value or o.text
        elseif o ~= nil then
            value = o
        end
    elseif el.type == 'imageboxcontainer' then
        out.action = 'child-click'
        local idx = math.floor(tonumber(d.index) or 0)
        out.child = data.items and data.items[idx] or nil
    end
    out.value = value
    if VALUE_TYPES[el.type] and data.persist ~= false then data.value = value end
    if el.type == 'button' or el.type == 'pagearrows' or el.type == 'arrows' or el.type == 'slider'
        or el.type == 'toggle' or el.type == 'checkbox' or el.type == 'gridslider' then
        playSound(data.sound)
    end
    if el.callback then
        local cb = el.callback
        CreateThread(function() Helpers.SafeCall(cb, out, el.api) end)
    end
end

-- ------------------------------------------------------------ pages
local function newPage(menu, pageID)
    local page = { id = pageID ~= nil and pageID or nextId('page'), menu = menu, elements = {}, byId = {} }
    local api = { id = page.id, pageID = page.id, menuID = menu.id }

    function api.RegisterElement(_, elType, data, cb)
        local el = newElement(page, elType, data, cb)
        if page.byId[el.id] then
            -- same id again replaces the old element in place
            for i, old in ipairs(page.elements) do
                if old == page.byId[el.id] then page.elements[i] = el end
            end
        else
            page.elements[#page.elements + 1] = el
        end
        page.byId[el.id] = el
        resendIfShown(page)
        return el.api
    end

    function api.RouteTo()
        if openMenu ~= menu then
            -- routing a closed menu just picks the page it opens on next
            menu.nextPage = page
            return
        end
        showPage(menu, page)
        fire(menu, 'topage', 'FeatherMenu:Page:RoutedTo', routedEvent(menu, page))
    end

    function api.UnRegister()
        menu.pages[page.id] = nil
        for i = #menu.pageOrder, 1, -1 do
            if menu.pageOrder[i] == page.id then table.remove(menu.pageOrder, i) end
        end
        if isShown(page) then closeMenu() end
    end

    function api.getElementClass(_, id)
        local el = page.byId[tostring(id)]
        return el and el.api or nil
    end

    page.api = api
    return page
end

-- ------------------------------------------------------------ menus
local function newMenu(menuID, config, callbacks, owner)
    local menu = {
        id = menuID, config = type(config) == 'table' and config or {},
        callbacks = callbacks, pages = {}, pageOrder = {}, owner = owner,
    }
    local api = { id = menu.id, menuID = menu.id }

    function api.RegisterPage(_, pageID)
        local page = newPage(menu, pageID)
        if not menu.pages[page.id] then menu.pageOrder[#menu.pageOrder + 1] = page.id end
        menu.pages[page.id] = page
        return page.api
    end

    function api.Open(_, opts)
        opts = type(opts) == 'table' and opts or {}
        if opts.startupPage == nil and menu.nextPage then opts.startupPage = menu.nextPage.api end
        menu.nextPage = nil
        return openMenuWith(menu, opts)
    end

    function api.Close(_, opts)
        if openMenu == menu then closeMenu(opts) end
    end

    function api.UnRegister()
        if openMenu == menu then closeMenu() end
        if menus[menu.id] == menu then menus[menu.id] = nil end
    end

    function api.isOpen()
        return openMenu == menu
    end

    menu.api = api
    return menu
end

function Feather.RegisterMenu(_, menuID, config, callbacks)
    menuID = menuID ~= nil and menuID or nextId('menu')
    local old = menus[menuID]
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if old then
        -- registering the same id again keeps its pages, takes the new look and callbacks
        old.config = type(config) == 'table' and config or old.config
        old.callbacks = callbacks or old.callbacks
        old.owner = owner
        return old.api
    end
    local menu = newMenu(menuID, config, callbacks, owner)
    menus[menuID] = menu
    return menu.api
end

--- FeatherMenu:Notify({ message, type, autoClose, position }, cb)
function Feather.Notify(_, cfg, cb)
    if type(cfg) == 'string' then cfg = { message = cfg } end
    cfg = type(cfg) == 'table' and cfg or {}
    local id = nextId('toast')
    if cb then toasts[id] = cb end
    Helpers.Send('featherNotify', {
        id = id,
        message = cfg.message or cfg.text or '',
        type = cfg.type or 'default',
        autoClose = cfg.autoClose,
        position = cfg.position or 'top-right',
        hideProgressBar = cfg.hideProgressBar,
    })
    return id
end

function Feather.isAnyMenuOpen()
    return openMenu ~= nil
end

function Feather.CloseAll()
    closeMenu()
end

-- ------------------------------------------------------------ from the page
local function findElement(d)
    if not openMenu or not openPage or type(d) ~= 'table' then return nil end
    if d.menuID ~= openMenu.id or d.pageID ~= openPage.id then return nil end
    return openPage.byId[tostring(d.id)]
end

RegisterNUICallback('featherEvent', function(d, reply)
    reply('ok')
    local el = findElement(d)
    if el then elementEvent(el, d) end
end)

RegisterNUICallback('featherClose', function(d, reply)
    reply('ok')
    if not openMenu then return end
    if type(d) == 'table' and d.menuID ~= nil and d.menuID ~= openMenu.id then return end
    if (openMenu.config or {}).canclose == false then return end
    closeMenu()
end)

RegisterNUICallback('featherKey', function(d, reply)
    reply('ok')
    if not openMenu or type(d) ~= 'table' then return end
    local kc = (openMenu.config or {}).keyclicks
    local fn = type(kc) == 'table' and kc[d.key] or nil
    if fn then CreateThread(function() Helpers.SafeCall(fn) end) end
end)

RegisterNUICallback('featherToast', function(d, reply)
    reply('ok')
    if type(d) ~= 'table' then return end
    local cb = toasts[d.id]
    if not cb then return end
    if d.type == 'closed' then toasts[d.id] = nil end
    CreateThread(function() Helpers.SafeCall(cb, { id = d.id, type = d.type }) end)
end)

-- A script stopped: drop its menus, and close the open one if it was its.
AddEventHandler('onClientResourceStop', function(res)
    for id, menu in pairs(menus) do
        if menu.owner == res then
            if openMenu == menu then
                menu.callbacks = nil
                closeMenu()
            end
            menus[id] = nil
        end
    end
end)

-- ------------------------------------------------------------ export
local function initiate()
    return Feather
end

-- answered only as exports['feather-menu'].initiate(): MULTIhelpers' own 'initiate' is vorp_progressbar's
Helpers.ExportAs('initiate', initiate, { 'feather-menu' })
