-- ============================================================
-- MULTIserver :: client
-- Player list (/players) and server info (/info). The page only
-- shows what the server sends.
-- ============================================================

local open = nil   -- 'players' | 'info' | nil

local function close()
    if not open then return end
    open = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function show(mode, data)
    open = mode
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', mode = mode, data = data, L = _LT(), lang = _LCode() })
end

local function openPlayers()
    if open == 'players' then return close() end
    local data = lib.callback.await('MULTIserver:players', false)
    if data == false then return end   -- asked too fast
    if not data then return end
    show('players', data)
end

local function openInfo()
    if open == 'info' then return close() end
    local data = lib.callback.await('MULTIserver:info', false)
    if not data then return end
    show('info', data)
end

--- Key-settings binding; PageDown is never bound.
local function mapKey(command, label, key)
    if type(key) ~= 'string' then return end
    if key:upper() == 'PAGEDOWN' then
        print('^1[MULTIserver]^7 ' .. _L('pagedown_refused'))
        key = ''
    end
    RegisterKeyMapping(command, label, 'keyboard', key)
end

if Config.PlayerList.Enabled then
    RegisterCommand(Config.PlayerList.Command, openPlayers, false)
    mapKey(Config.PlayerList.Command, _L('key_players'), Config.PlayerList.Key)
end

if Config.Info.Enabled then
    RegisterCommand(Config.Info.Command, openInfo, false)
    mapKey(Config.Info.Command, _L('key_info'), Config.Info.Key)
end

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    if open ~= 'players' then return cb({}) end
    cb(lib.callback.await('MULTIserver:players', false) or {})
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
