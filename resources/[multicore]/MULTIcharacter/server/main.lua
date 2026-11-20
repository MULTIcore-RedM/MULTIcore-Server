-- ============================================================
-- MULTIcharacter :: server glue
-- Characters are listed, created, selected and deleted through
-- MULTIcore's own callbacks (MULTIcore:chars:*). This file only adds
-- the slot count and the logout command.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- never save a player's position while they stand in the select scene, so "last location"
-- always means where they really were (MULTIcore keeps the previous position instead)
CreateThread(function()
    local ok = pcall(function()
        exports.MULTIcore:AddNoSaveArea(Config.Scene.hidePlayerAt, Config.NoSaveRadius or 100.0)
    end)
    if not ok then print('^3[MULTIcharacter] MULTIcore has no AddNoSaveArea; positions in the select scene may be saved^7') end
end)

-- Slot count for this account: the smaller of Config.MaxCharacters and the
-- account's own slot count (from MULTIcore).
lib.callback.register('MULTIcharacter:slots', function(src)
    local n = tonumber(exports.MULTIcore:GetAccountSlots(src))
    if n and n > 0 and n < Config.MaxCharacters then return n end
    return Config.MaxCharacters
end)

-- ------------------------------------------------------------
-- Logout
-- ------------------------------------------------------------
local lastLogout = {}

local function logout(src)
    local cfg = Config.Logout
    if cfg.ace and not IsPlayerAceAllowed(src, cfg.ace) then return end
    local now = os.time()
    if lastLogout[src] and now - lastLogout[src] < (cfg.cooldown or 0) then
        exports.MULTIcore:Notify(src, _L('logout_cooldown'), Config.NotifyError)
        return
    end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return end
    if not cfg.allowDead and P.PlayerData.metadata and P.PlayerData.metadata.isdead then
        exports.MULTIcore:Notify(src, _L('logout_dead'), Config.NotifyError)
        return
    end
    lastLogout[src] = now
    -- saves, fires both unload events, then sends MULTIcore:client:loggedOut
    exports.MULTIcore:LogoutCharacter(src)
end

RegisterNetEvent('MULTIcharacter:server:logout', function()
    logout(source)
end)

if Config.Logout.command then
    RegisterCommand(Config.Logout.command, function(src)
        if src > 0 then logout(src) end
    end, false)
end

AddEventHandler('playerDropped', function()
    lastLogout[source] = nil
end)
