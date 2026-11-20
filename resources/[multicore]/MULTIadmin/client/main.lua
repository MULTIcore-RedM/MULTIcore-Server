-- ============================================================
-- MULTIadmin :: client - menu
-- Opens the NUI only after the server says yes, and forwards every
-- button to the server. Self tools (client/self.lua) are applied here
-- only after the server allowed and logged them.
-- ============================================================

Admin = { open = false, allowed = {} }

--- MULTIcore notification (the only way MULTI scripts notify).
function Admin.Notify(text, ntype)
    exports.MULTIcore:Notify({ text = text, title = _L('admin_title'), type = ntype or 'info', duration = Config.NotifyDuration })
end

--- Runs an action on the server. Returns the reply table { ok, msg, data }.
function Admin.Run(action, data)
    local res = lib.callback.await('MULTIadmin:action', false, action, data)
    if type(res) ~= 'table' then res = { ok = false, msg = _L('no_answer') } end
    if res.msg then Admin.Notify(res.msg, res.ok and 'success' or 'error') end
    return res
end

local function send(action, payload)
    SendNUIMessage({ action = action, data = payload })
end
Admin.Send = send

local function close()
    if not Admin.open then return end
    Admin.open = false
    SetNuiFocus(false, false)
    send('close')
end

local function open()
    if Admin.open then return close() end
    local data = lib.callback.await('MULTIadmin:open', false)
    if not data then
        Admin.Notify(_L('not_staff'), 'error')
        return
    end
    Admin.allowed = data.allowed or {}
    data.state = Admin.SelfState()
    Admin.open = true
    SetNuiFocus(true, true)
    send('open', data)
end

RegisterCommand(Config.Command, open, false)

--- Key-settings binding; PageDown is never bound.
function Admin.MapKey(command, label, key)
    if key == false or key == nil then return end
    if type(key) == 'string' and key:upper() == 'PAGEDOWN' then
        print('^1[MULTIadmin]^7 ' .. _L('pagedown_refused'))
        key = ''
    end
    RegisterKeyMapping(command, label, 'keyboard', key)
end
Admin.MapKey(Config.Command, _L('key_open'), Config.OpenKey)

-- ---------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('MULTIadmin:players', false) or {})
end)

-- Player / server actions: the server does all the work
RegisterNUICallback('action', function(body, cb)
    local action = type(body) == 'table' and body.action or nil
    local data = type(body) == 'table' and type(body.data) == 'table' and body.data or {}
    if type(action) ~= 'string' then return cb({ ok = false }) end
    local res = Admin.Run(action, data)
    if res.ok and (action == 'goto' or action == 'charmenu' or (action == 'spectate' and not data.stop)) then close() end
    cb(res)
end)

-- Self tools: ask the server, then apply here
RegisterNUICallback('self', function(body, cb)
    local name = type(body) == 'table' and body.name or nil
    local fn = name and Admin.SelfTools[name]
    if not fn then return cb({ ok = false }) end
    local ok, closeMenu = fn(type(body.data) == 'table' and body.data or {})
    if closeMenu then close() end
    cb({ ok = ok == true, state = Admin.SelfState() })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Admin.open then SetNuiFocus(false, false) end
end)
