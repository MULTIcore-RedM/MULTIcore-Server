-- ============================================================
-- MULTIlaw :: rsg-lawman and rsg-prison (client side)
-- Client event names follow rsg-lawman 2.0.6 / rsg-prison 2.0.3 and the
-- RSG v2 scripts that fire them (rsg-radialmenu, rsg-adminmenu, rsg-mdt).
-- Anything that changes state is asked of the server.
-- ============================================================

local function dbg(...) if Config.Debug then print('^5[MULTIlaw]^7', ...) end end
local function ignored(name) dbg('ignored client event ' .. name) end

local function nearest(dist, fn)
    local target = LawC.NearestPlayer(dist)
    if not target then return LawC.notify(_L('no_player'), 'error') end
    CreateThread(function() fn(target) end)
end

---------------------------------
-- the lawman's own client (rsg-radialmenu law buttons, rsg-lawman commands)
---------------------------------
RegisterNetEvent('rsg-lawman:client:cuffplayer', function() nearest(Config.Cuff.Distance, LawC.Cuff) end)
RegisterNetEvent('rsg-lawman:client:escortplayer', function() nearest(Config.Escort.Distance, LawC.Escort) end)
RegisterNetEvent('rsg-lawman:client:searchplayer', function() nearest(Config.Search.Distance, LawC.Search) end)
-- (playerId, time) jails that player; with no arguments asks for the nearest one
RegisterNetEvent('rsg-lawman:client:jailplayer', function(playerId, time)
    if playerId and time then
        CreateThread(function()
            LawC.say(lib.callback.await('MULTIlaw:action', false, 'jail', tonumber(playerId), { minutes = tonumber(time), place = 'auto' }))
        end)
    else
        nearest(Config.Jail.Distance, LawC.JailDialog)
    end
end)
RegisterNetEvent('rsg-lawman:client:mainmenu', function() CreateThread(LawC.OfficeMenu) end)
RegisterNetEvent('rsg-lawman:client:openstorage', function()
    local job = LawC.pdata().job or {}
    TriggerServerEvent('rsg-lawman:server:storage', job.name)
end)
RegisterNetEvent('rsg-lawman:client:lawbadge', function() LawC.ToggleBadge() end)
AddEventHandler('rsg-lawman:client:ToggleDuty', function() TriggerServerEvent('RSGCore:ToggleDuty') end)
RegisterNetEvent('rsg-lawman:client:openarmoury', function() ignored('openarmoury (use MULTIstores)') end)

-- an alert sent to this player (rsg-lawman's /testalert and other scripts): (coords, text)
RegisterNetEvent('rsg-lawman:client:lawmanAlert', function(coords, text)
    if coords then LawC.ShowAlert(coords, text or _L('alert_default')) end
end)

---------------------------------
-- the prisoner's client
---------------------------------
-- rsg-adminmenu cuffs through this (playerId = the admin); the server checks it really is an admin
RegisterNetEvent('rsg-lawman:client:getcuffed', function(playerId)
    TriggerServerEvent('MULTIlaw:server:adminCuff', playerId)
end)
-- leading is started by the server only
RegisterNetEvent('rsg-lawman:client:getescorted', function() ignored('getescorted') end)

-- rsg-mdt (and others) wrote metadata.injail on the server, then send this: serve it
RegisterNetEvent('rsg-lawman:client:sendtojail', function()
    if not LawC.IsJailed() then TriggerServerEvent('MULTIlaw:server:metaJail') end
end)
RegisterNetEvent('rsg-prison:client:Enter', function()
    if not LawC.IsJailed() then TriggerServerEvent('MULTIlaw:server:metaJail') end
end)
-- "set free": the server lets him go only when the time is served
RegisterNetEvent('rsg-prison:client:freedom', function() TriggerServerEvent('rsg-prison:server:FreePlayer') end)

RegisterNetEvent('rsg-prison:client:prisonclothes', function() ignored('prisonclothes') end)
RegisterNetEvent('rsg-prison:client:menu', function() ignored('menu') end)
RegisterNetEvent('rsg-prison:client:shop', function() ignored('shop') end)
RegisterNetEvent('rsg-prison:client:telegrammenu', function() ignored('telegrammenu') end)
