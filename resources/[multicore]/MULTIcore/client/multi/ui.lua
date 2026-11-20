-- ============================================================
-- MULTIcore :: menus and dialogs (client)
-- MULTIcore's own black-and-white versions of ox_lib's context menu,
-- input dialog, alert dialog, progress bar and text prompt, drawn by
-- html/ui (on the core's page). Same arguments and results as ox_lib, so
-- @MULTIcore/lib/ui.lua can point a script's lib.* calls here.
--
--   exports.MULTIcore:registerContext(ctx)   exports.MULTIcore:showContext(id)
--   exports.MULTIcore:hideContext(onExit)    exports.MULTIcore:getOpenContextMenu()
--   exports.MULTIcore:inputDialog(heading, rows, options)  -> { values } | nil
--   exports.MULTIcore:closeInputDialog()
--   exports.MULTIcore:alertDialog(data)       -> 'confirm' | 'cancel'
--   exports.MULTIcore:closeAlertDialog()
--   exports.MULTIcore:progressBar(data)       -> true (done) | false (cancelled)
--   exports.MULTIcore:progressActive()        exports.MULTIcore:cancelProgress()
--   exports.MULTIcore:showTextUI(text, opts)  exports.MULTIcore:hideTextUI()
--   exports.MULTIcore:isTextUIOpen()          -> open, text
-- Written fresh for MULTIcore (GPL v3).
-- ============================================================

local contexts = {}      -- [id] = context (ox_lib shape)
local openId = nil       -- id of the context menu on screen
local dialog = nil       -- promise of the open input / alert dialog
local dialogKind = nil   -- 'input' | 'alert'
local progress = nil     -- { cancel = bool } while a progress bar runs
local textOpen, textShown = false, nil

-- the page's own words (locales/ui_*.lua), sent with every message
local WORDS = { 'ui_back', 'ui_confirm', 'ui_cancel', 'ui_close', 'ui_select', 'ui_required' }
local words

local function nui(msg)
    if not words then
        words = {}
        for _, k in ipairs(WORDS) do words[k] = _L(k) end
    end
    msg.words = words
    SendNUIMessage(msg)
end

local function focus(on)
    SetNuiFocus(on, on)
end

-- ---------------------------------------------------------------
-- context menus
-- ---------------------------------------------------------------

-- options may be an array or a { [title] = option } map (ox_lib allows both)
local function optionList(ctx)
    local list = {}
    if type(ctx.options) ~= 'table' then return list end
    if ctx.options[1] ~= nil then
        for _, o in ipairs(ctx.options) do list[#list + 1] = o end
    else
        local keys = {}
        for k in pairs(ctx.options) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local o = ctx.options[k]
            if type(o) == 'table' then
                o.title = o.title or tostring(k)
                list[#list + 1] = o
            end
        end
    end
    return list
end

-- metadata: array of strings / { label, value }, or a { [label] = value } map
local function metaList(m)
    if type(m) ~= 'table' then return nil end
    local out = {}
    if m[1] ~= nil then
        for _, v in ipairs(m) do
            if type(v) == 'table' then
                out[#out + 1] = { label = tostring(v.label or ''), value = v.value ~= nil and tostring(v.value) or nil, progress = tonumber(v.progress) }
            else
                out[#out + 1] = { label = tostring(v) }
            end
        end
    else
        for k, v in pairs(m) do out[#out + 1] = { label = tostring(k), value = tostring(v) } end
        table.sort(out, function(a, b) return a.label < b.label end)
    end
    return out
end

local function iconName(i)
    if type(i) ~= 'string' then return nil end
    return i
end

local function registerContext(ctx)
    if type(ctx) ~= 'table' then return end
    if ctx.id then
        contexts[ctx.id] = ctx
    else
        for _, c in pairs(ctx) do
            if type(c) == 'table' and c.id then contexts[c.id] = c end
        end
    end
end

local function showContext(id)
    local ctx = contexts[id]
    if not ctx then
        print(('^1[MULTIcore ui] no context menu with id %s^7'):format(tostring(id)))
        return
    end
    openId = id
    local rows = {}
    for i, o in ipairs(optionList(ctx)) do
        local clickable = not o.disabled and not o.readOnly and (o.onSelect or o.event or o.serverEvent or o.menu) and true or false
        rows[i] = {
            title = o.title and tostring(o.title) or '',
            description = o.description and tostring(o.description) or nil,
            icon = iconName(o.icon),
            arrow = (o.arrow or o.menu) and true or false,
            disabled = o.disabled and true or false,
            readOnly = (o.readOnly or not clickable) and true or false,
            progress = tonumber(o.progress),
            metadata = metaList(o.metadata),
            image = type(o.image) == 'string' and o.image or nil,
        }
    end
    focus(true)
    nui({ action = 'ui:context', title = ctx.title and tostring(ctx.title) or '', back = ctx.menu ~= nil, canClose = ctx.canClose ~= false, rows = rows })
end

local function hideContext(runExit)
    local id = openId
    if not id then return end
    openId = nil
    nui({ action = 'ui:contextHide' })
    if not dialog then focus(false) end
    local ctx = contexts[id]
    if runExit and ctx and ctx.onExit then ctx.onExit() end
end

RegisterNUICallback('ui:contextPick', function(data, cb)
    cb('ok')
    local ctx = openId and contexts[openId]
    if not ctx then return end
    local o = optionList(ctx)[tonumber(data and data.index) or 0]
    if not o or o.disabled or o.readOnly then return end
    if o.menu then
        -- a sub menu opens in place; its own back row returns here
        return showContext(o.menu)
    end
    hideContext(false)
    if o.onSelect then o.onSelect(o.args) end
    if o.event then TriggerEvent(o.event, o.args) end
    if o.serverEvent then TriggerServerEvent(o.serverEvent, o.args) end
end)

RegisterNUICallback('ui:contextBack', function(_, cb)
    cb('ok')
    local ctx = openId and contexts[openId]
    if not ctx or not ctx.menu then return end
    if ctx.onBack then ctx.onBack() end
    showContext(ctx.menu)
end)

RegisterNUICallback('ui:contextClose', function(_, cb)
    cb('ok')
    local ctx = openId and contexts[openId]
    if ctx and ctx.canClose == false then return end
    hideContext(true)
end)

-- ---------------------------------------------------------------
-- input and alert dialogs (block until answered, like ox_lib)
-- ---------------------------------------------------------------

local ROW_TYPES = { input = true, number = true, checkbox = true, select = true, ['multi-select'] = true,
    slider = true, textarea = true, color = true, date = true, time = true }

local function inputDialog(heading, rows, options)
    if dialog then return nil end
    local out = {}
    for i, r in ipairs(type(rows) == 'table' and rows or {}) do
        if type(r) ~= 'table' then r = { type = 'input', label = tostring(r) } end
        local t = ROW_TYPES[r.type] and r.type or 'input'
        local opts
        if type(r.options) == 'table' then
            opts = {}
            for j, o in ipairs(r.options) do
                opts[j] = { value = o.value, label = tostring(o.label or o.value) }
            end
        end
        out[i] = {
            type = t, label = r.label and tostring(r.label) or '', description = r.description and tostring(r.description) or nil,
            placeholder = r.placeholder and tostring(r.placeholder) or nil, default = r.default, checked = r.checked and true or false,
            required = r.required and true or false, disabled = r.disabled and true or false, password = r.password and true or false,
            min = tonumber(r.min), max = tonumber(r.max), step = tonumber(r.step), options = opts, icon = iconName(r.icon),
        }
    end
    dialog = promise.new()
    dialogKind = 'input'
    focus(true)
    nui({ action = 'ui:input', heading = heading and tostring(heading) or '', rows = out,
        allowCancel = not (type(options) == 'table' and options.allowCancel == false) })
    local result = Citizen.Await(dialog)
    dialog, dialogKind = nil, nil
    if not openId then focus(false) end
    return result
end

RegisterNUICallback('ui:inputDone', function(data, cb)
    cb('ok')
    if not dialog or dialogKind ~= 'input' then return end
    if type(data) ~= 'table' or data.cancel then return dialog:resolve(nil) end
    -- JSON nulls become holes, as ox_lib's results do for empty fields
    local values = {}
    for i, v in pairs(data.values or {}) do
        local n = tonumber(i)
        if n then values[n + 1] = v end
    end
    dialog:resolve(values)
end)

local function closeInputDialog()
    if dialog and dialogKind == 'input' then
        nui({ action = 'ui:dialogHide' })
        dialog:resolve(nil)
    end
end

local function alertDialog(data)
    if dialog or type(data) ~= 'table' then return 'cancel' end
    dialog = promise.new()
    dialogKind = 'alert'
    focus(true)
    local labels = type(data.labels) == 'table' and data.labels or {}
    nui({ action = 'ui:alert', header = data.header and tostring(data.header) or '', content = data.content and tostring(data.content) or '',
        cancel = data.cancel and true or false, confirm = labels.confirm and tostring(labels.confirm) or nil,
        cancelLabel = labels.cancel and tostring(labels.cancel) or nil })
    local result = Citizen.Await(dialog)
    dialog, dialogKind = nil, nil
    if not openId then focus(false) end
    return result
end

RegisterNUICallback('ui:alertDone', function(data, cb)
    cb('ok')
    if not dialog or dialogKind ~= 'alert' then return end
    dialog:resolve(type(data) == 'table' and data.confirm and 'confirm' or 'cancel')
end)

local function closeAlertDialog()
    if dialog and dialogKind == 'alert' then
        nui({ action = 'ui:dialogHide' })
        dialog:resolve('cancel')
    end
end

-- ---------------------------------------------------------------
-- progress bar (animation, prop and control lock like ox_lib)
-- ---------------------------------------------------------------

-- control hashes: redm-info Controls.cs
local LOCK = {
    move = { 0x4D8FB4C1, 0xFDA83190, 0x8FFC75D6, 0xD9D0E1C0, 0xDB096B85, 0xDE794E3E }, -- MoveLr, MoveUd, Sprint, Jump, Duck, Cover
    sprint = { 0x8FFC75D6 },                                                          -- Sprint
    car = { 0x5B9FD4E2, 0x6E1F639B, 0xFEFAB9B4, 0x126796EB, 0x3BBDEFEF, 0x5AA007D7 }, -- VehAccelerate, VehBrake, VehExit, HorseMoveLr, HorseMoveUd, HorseSprint
    combat = { 0x07CE1E61, 0xF84FA74F, 0xE30CD707, 0xB2F377E8, 0x60C81CDE, 0x61470051, 0xAC4BD4F1 }, -- Attack, Aim, Reload, MeleeAttack, HorseAttack, HorseAim, OpenWheelMenu
    mouse = { 0xA987235F, 0xD2047988 },                                               -- LookLr, LookUd
}
local CANCEL_KEY = 0x8CC9CD42   -- X (shared/keybinds.lua)

local function spawnProps(prop, ped)
    local list, made = {}, {}
    if type(prop) ~= 'table' then return made end
    if prop.model then list[1] = prop else list = prop end
    local here = GetEntityCoords(ped)
    for _, p in ipairs(list) do
        if type(p) == 'table' and p.model then
            local model = type(p.model) == 'number' and p.model or joaat(p.model)
            if lib.requestModel(model, 5000) then
                local obj = CreateObject(model, here.x, here.y, here.z, true, true, false)
                local pos = p.pos or vector3(0.0, 0.0, 0.0)
                local rot = p.rot or vector3(0.0, 0.0, 0.0)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone or 60309), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
                SetModelAsNoLongerNeeded(model)
                made[#made + 1] = obj
            end
        end
    end
    return made
end

local function progressBar(data)
    if progress or type(data) ~= 'table' then return false end
    local ped = PlayerPedId()
    if not data.useWhileDead and IsEntityDead(ped) then return false end
    local duration = tonumber(data.duration) or 1000
    progress = { cancel = false }
    local p = progress

    -- animation or scenario
    local anim = data.anim
    if type(anim) == 'table' then
        if anim.dict and anim.clip and lib.requestAnimDict(anim.dict, 5000) then
            TaskPlayAnim(ped, anim.dict, anim.clip, anim.blendIn or 3.0, anim.blendOut or 1.0, anim.duration or -1, anim.flag or 49, anim.playbackRate or 0, false, false, false, '', false)
            RemoveAnimDict(anim.dict)
        elseif anim.scenario then
            -- TASK_START_SCENARIO_IN_PLACE_HASH (femga natives.json)
            Citizen.InvokeNative(0x524B54361229154F, ped, joaat(anim.scenario), -1, true, 0, GetEntityHeading(ped), false)
        end
    end
    local props = spawnProps(data.prop, ped)

    local locks = {}
    local d = type(data.disable) == 'table' and data.disable or {}
    for k, on in pairs(d) do
        if on and LOCK[k] then for _, c in ipairs(LOCK[k]) do locks[#locks + 1] = c end end
    end

    nui({ action = 'ui:progress', label = data.label and tostring(data.label) or '', duration = duration, canCancel = data.canCancel and true or false })

    local ends = GetGameTimer() + duration
    while GetGameTimer() < ends and not p.cancel do
        for _, c in ipairs(locks) do DisableControlAction(0, c, true) end
        if data.canCancel then
            DisableControlAction(0, CANCEL_KEY, true)
            if IsDisabledControlJustPressed(0, CANCEL_KEY) then p.cancel = true end
        end
        if not data.useWhileDead and IsEntityDead(PlayerPedId()) then p.cancel = true end
        Wait(0)
    end

    nui({ action = 'ui:progressHide' })
    for _, obj in ipairs(props) do
        if DoesEntityExist(obj) then DetachEntity(obj, true, true) DeleteEntity(obj) end
    end
    if type(anim) == 'table' then
        if anim.dict and anim.clip then StopAnimTask(ped, anim.dict, anim.clip, 1.0) else ClearPedTasks(ped) end
    end
    progress = nil
    return not p.cancel
end

local function progressActive() return progress ~= nil end
local function cancelProgress() if progress then progress.cancel = true end end

-- ---------------------------------------------------------------
-- text prompt (bottom centre; "[E] Open" shows E in a key box)
-- ---------------------------------------------------------------

local function showTextUI(text, opts)
    text = tostring(text or '')
    textOpen, textShown = true, text
    nui({ action = 'ui:text', text = text, icon = type(opts) == 'table' and iconName(opts.icon) or nil })
end

local function hideTextUI()
    if not textOpen then return end
    textOpen, textShown = false, nil
    nui({ action = 'ui:textHide' })
end

local function isTextUIOpen() return textOpen, textShown end

-- ---------------------------------------------------------------
-- exports
-- ---------------------------------------------------------------

exports('registerContext', registerContext)
exports('showContext', showContext)
exports('hideContext', hideContext)
exports('getOpenContextMenu', function() return openId end)
exports('inputDialog', inputDialog)
exports('closeInputDialog', closeInputDialog)
exports('alertDialog', alertDialog)
exports('closeAlertDialog', closeAlertDialog)
exports('progressBar', progressBar)
exports('progressCircle', progressBar)
exports('progressActive', progressActive)
exports('cancelProgress', cancelProgress)
exports('showTextUI', showTextUI)
exports('hideTextUI', hideTextUI)
exports('isTextUIOpen', isTextUIOpen)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if openId or dialog then SetNuiFocus(false, false) end
end)
