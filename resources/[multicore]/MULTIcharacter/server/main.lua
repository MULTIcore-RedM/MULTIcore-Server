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

-- ------------------------------------------------------------
-- Private select scene / character creator
-- Each player gets a routing bucket of their own while they pick or create a character, so
-- players in the scene or the creator at the same time don't see each other.
-- ------------------------------------------------------------
local private = {}   -- [src] = bucket they were in before

local function leavePrivate(src)
    local before = private[src]
    if before == nil then return end
    private[src] = nil
    SetPlayerRoutingBucket(src, before)
end

RegisterNetEvent('MULTIcharacter:server:privateScene', function(on)
    local src = source
    if not Config.PrivateScene then return end
    if on ~= true then
        leavePrivate(src)
        return
    end
    if private[src] ~= nil then return end
    -- only before a character is loaded: a playing character can't hide from everyone with it
    if RSGCore.Functions.GetPlayer(src) then return end
    local bucket = (tonumber(Config.PrivateBucketBase) or 50000) + src
    private[src] = GetPlayerRoutingBucket(src)
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(src, bucket)
end)

-- the client normally puts the player back when they spawn; if it never does (crash, script
-- error), a loaded character is put back with everyone else a little later
CreateThread(function()
    while true do
        Wait(15000)
        for src in pairs(private) do
            -- a loaded character still in the spawn picker stays; once out in the world it is put back
            if RSGCore.Functions.GetPlayer(src) then
                local ped = GetPlayerPed(src)
                local away = ped ~= 0 and #(GetEntityCoords(ped) - Config.Scene.hidePlayerAt) > (Config.NoSaveRadius or 100.0)
                if away then leavePrivate(src) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(private) do leavePrivate(src) end
end)

AddEventHandler('playerDropped', function()
    lastLogout[source] = nil
    private[source] = nil
end)
