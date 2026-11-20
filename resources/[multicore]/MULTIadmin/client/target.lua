-- ============================================================
-- MULTIadmin :: client - things the server does to a player
-- These events only ever come from the server (clients can't send
-- client events to other clients), after the admin's permission check.
-- ============================================================

local SP = Config.Spectate

-- teleport (goto for the admin, bring for the target)
RegisterNetEvent('MULTIadmin:client:teleport', function(c, waitForWorld)
    if type(c) ~= 'table' or not tonumber(c.x) then return end
    Admin.Teleport(c, waitForWorld)
end)

-- freeze: kept on until the server says otherwise (survives respawn).
-- The server sends the notification.
local frozen = false
RegisterNetEvent('MULTIadmin:client:freeze', function(on)
    frozen = on == true
    FreezeEntityPosition(PlayerPedId(), frozen)
    if not frozen then return end
    CreateThread(function()
        while frozen do
            FreezeEntityPosition(PlayerPedId(), true)
            Wait(Config.StateRecheckMs)
        end
        FreezeEntityPosition(PlayerPedId(), false)
    end)
end)

RegisterNetEvent('MULTIadmin:client:kill', function()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 0, 0)   -- 0 health kills the ped (native docs)
end)

-- Health fallback (Config.LocalHealthFallback); the core events fire as well
RegisterNetEvent('MULTIadmin:client:heal', function() Admin.LocalHeal() end)
RegisterNetEvent('MULTIadmin:client:revive', function() Admin.LocalRevive() end)

-- ---------------------------------------------------------------
-- spectate
-- ---------------------------------------------------------------

local spec = nil   -- { target, back = coords }

local function restoreSelf()
    local back = spec and spec.back
    spec = nil   -- ends the follow loop first
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    SetEntityCollision(ped, true, true)
    if back then Admin.Teleport(back, true) end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, not Admin.SelfState().invisible)
    SetEntityInvincible(ped, Admin.SelfState().god)
    lib.hideTextUI()
end

local function targetPed(target)
    local pl = GetPlayerFromServerId(target)
    if pl == -1 then return 0 end
    local p = GetPlayerPed(pl)
    return (p ~= 0 and DoesEntityExist(p)) and p or 0
end

local function startSpectate(target, c)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    spec = spec or { back = { x = me.x, y = me.y, z = me.z, w = GetEntityHeading(ped) } }
    spec.target = target
    SetEntityVisible(ped, false)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    -- get close enough for the target to stream in
    SetEntityCoords(ped, c.x, c.y, c.z - SP.Depth, false, false, false, false)

    local timeout = GetGameTimer() + SP.StreamTimeoutMs
    local tped = targetPed(target)
    while tped == 0 and GetGameTimer() < timeout do
        Wait(0)
        tped = targetPed(target)
    end
    if tped == 0 then
        Admin.Notify(_L('spectate_fail'), 'error')
        Admin.Run('spectate', { stop = true })
        return
    end
    NetworkSetInSpectatorMode(true, tped)
    lib.showTextUI(_L('spectate_text', GetPlayerName(GetPlayerFromServerId(target)) or tostring(target)))

    CreateThread(function()
        while spec and spec.target == target do
            local tp = targetPed(target)
            if tp ~= 0 then
                -- keep the hidden ped under the target so it stays in range
                local tc = GetEntityCoords(tp)
                SetEntityCoords(PlayerPedId(), tc.x, tc.y, tc.z - SP.Depth, false, false, false, false)
                if tp ~= tped then tped = tp; NetworkSetInSpectatorMode(true, tp) end
            end
            for _ = 1, SP.FollowFrames do
                if not spec or spec.target ~= target then break end
                DisableControlAction(0, SP.StopControl, true)
                if IsDisabledControlJustPressed(0, SP.StopControl) then
                    Admin.Run('spectate', { stop = true })
                    break
                end
                Wait(0)
            end
        end
    end)
end

RegisterNetEvent('MULTIadmin:client:spectate', function(on, target, c)
    if on and tonumber(target) and type(c) == 'table' then
        startSpectate(tonumber(target), c)
    elseif spec then
        restoreSelf()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if spec then NetworkSetInSpectatorMode(false, PlayerPedId()) end
    if frozen then FreezeEntityPosition(PlayerPedId(), false) end
end)
