-- ============================================================
-- MULTIemotes :: walk styles (client)
-- The server keeps the chosen style in the character's metadata and
-- in the player's state bag (Config.WalkMetadataKey). Every client
-- puts it on that player's ped: when it changes, when the ped streams
-- in or is replaced (respawn), and after the own look is reloaded.
-- The state bag approach and the two loco natives follow RSG v2
-- rsg-radialmenu's walkstyles.lua (GPL v3, Rexshack-RedM / RSG, see CREDITS.md).
-- GPL v3.
-- ============================================================

local N = {
    SET_LOCO = 0x923583741DC87BCE,    -- _SET_PED_DESIRED_LOCO_FOR_MODEL
    SET_MOTION = 0x89F5E7ADECCCB49C,  -- _SET_PED_DESIRED_LOCO_MOTION_TYPE
    CLEAR_LOCO = 0x4FD80C3DD84B817B,  -- _CLEAR_PED_DESIRED_LOCO_FOR_MODEL
    CLEAR_MOTION = 0x58F7DB5BD8FA2288, -- _CLEAR_PED_DESIRED_LOCO_MOTION_TYPE
}
local KEY = Config.WalkMetadataKey
local applied = {} -- [serverId] = { ped = handle, id = walk id or false }

local function apply(ped, id)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local w = id and MEM.WalkById[id]
    if w then
        Citizen.InvokeNative(N.SET_LOCO, ped, w.loco)
        Citizen.InvokeNative(N.SET_MOTION, ped, w.motion)
    else
        Citizen.InvokeNative(N.CLEAR_LOCO, ped)
        Citizen.InvokeNative(N.CLEAR_MOTION, ped)
    end
    return true
end

local function sync(serverId, force)
    local ply = GetPlayerFromServerId(serverId)
    if ply == -1 then applied[serverId] = nil return end
    local id = Player(serverId).state[KEY]
    if id ~= nil and not MEM.WalkById[id] then id = nil end -- another script's style we don't know
    local ped = GetPlayerPed(ply)
    local was = applied[serverId]
    if not was and not id then return end -- never set by us: leave other scripts' loco alone
    if force or not was or was.ped ~= ped or was.id ~= (id or false) then
        if apply(ped, id) then applied[serverId] = { ped = ped, id = id or false } end
    end
end

--- The local player's walk style id, or nil.
function MEM.CurrentWalk()
    local id = LocalPlayer.state[KEY]
    return (id and MEM.WalkById[id]) and id or nil
end

--- Asks the server to set (id) or clear (nil) the local player's walk style.
function MEM.SetWalk(id)
    if id and not MEM.WalkById[id] then return false, 'err_walk_unknown' end
    local ok, err = lib.callback.await('MULTIemotes:setWalk', false, id or false)
    if ok then
        apply(cache.ped, id) -- instant feedback; the state bag follows
        applied[GetPlayerServerId(PlayerId())] = { ped = cache.ped, id = id or false }
        if id then MEM.Notify(_L('walk_set', _L('walk_' .. id)), 'success') else MEM.Notify(_L('walk_reset'), 'success') end
        return true
    end
    MEM.Notify(_L(err or 'err_failed'), 'error')
    return false, err
end

AddStateBagChangeHandler(KEY, nil, function(bagName)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    local serverId = GetPlayerServerId(ply)
    SetTimeout(0, function() sync(serverId, true) end) -- the new value is readable next tick
end)

-- catch-up: peds streaming in, respawns (new ped handle), late joins
CreateThread(function()
    while true do
        Wait(Config.WalkSyncMs)
        local seen = {}
        for _, ply in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(ply)
            seen[serverId] = true
            sync(serverId)
        end
        for serverId in pairs(applied) do
            if not seen[serverId] then applied[serverId] = nil end
        end
    end
end)

-- a look reload or a new model resets the loco: put the own style back on
local function reapplySelf()
    SetTimeout(Config.WalkReapplyDelayMs, function() sync(GetPlayerServerId(PlayerId()), true) end)
end
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', reapplySelf)
AddEventHandler('MULTIcore:client:lookApplied', reapplySelf)
RegisterNetEvent('MULTIemotes:client:reapplyWalk', reapplySelf)

---------------------------------
-- /walk
---------------------------------
if Config.Commands.Walk ~= '' then
    RegisterCommand(Config.Commands.Walk, function(_, args)
        if not args[1] then return MEM.OpenMenu('walk') end
        local text = table.concat(args, ' ')
        if MEM.Norm(text) == MEM.Norm(_L('walk_reset_word')) or MEM.Norm(text) == 'reset' then return MEM.SetWalk(nil) end
        local w = MEM.FindWalk(text)
        if not w then return MEM.Notify(_L('err_walk_unknown_name', text), 'error') end
        MEM.SetWalk(w.id)
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Walk, _L('help_walk'), { { name = 'style', help = _L('help_walk_name') } })
end
