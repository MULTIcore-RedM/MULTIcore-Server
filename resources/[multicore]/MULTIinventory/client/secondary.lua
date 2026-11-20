-- ============================================================
-- MULTIinventory :: client/secondary.lua
--
--   * Search conditions: reports this player's pose to the server in the replicated
--     player state bag `multiInvPose` = { handsUp, cuffed, hogtied, dead } (read by
--     server/secondary/search.lua). Only changes are sent.
--   * Search command (Config.Secondary.search.command, default /search): searches the
--     closest player; the server checks every rule again.
--   * Saddlebags: InvClient.saddlebag(netId) (called by the UI's saddlebag button)
--     sends the compat event vorp_inventory:Server:SaddleOpen with the horse's net id,
--     which RINGOstables handles (own horse, distance). Export OpenSaddlebag() / event
--     MULTIinventory:client:openSaddlebag do the same, falling back to the last mount nearby.
-- Exports (client): SearchClosestPlayer(), OpenSaddlebag(), GetPose()
-- ============================================================

InvSecondaryClient = InvSecondaryClient or {}

local function scfg() return (Config.Secondary and Config.Secondary.search) or {} end
local function sbcfg() return (Config.Secondary and Config.Secondary.saddlebags) or {} end

local function yes(v) return v == true or v == 1 end

local function handsUp(ped)
    for _, a in ipairs(scfg().handsUpAnims or {}) do
        if a.dict and a.anim and IsEntityPlayingAnim(ped, a.dict, a.anim, 3) then return true end
    end
    return false
end

function InvSecondaryClient.pose()
    local ped = PlayerPedId()
    return {
        handsUp = handsUp(ped),
        cuffed = yes(Citizen.InvokeNative(0x74E559B3BC910685, ped)),   -- IS_PED_CUFFED
        hogtied = yes(Citizen.InvokeNative(0x3AA24CCC0D451379, ped)),  -- IS_PED_HOGTIED
        dead = yes(IsEntityDead(ped)),
    }
end

CreateThread(function()
    local last
    while true do
        Wait(500)
        if scfg().enabled ~= false then
            local p = InvSecondaryClient.pose()
            local key = ('%d%d%d%d'):format(p.handsUp and 1 or 0, p.cuffed and 1 or 0, p.hogtied and 1 or 0, p.dead and 1 or 0)
            if key ~= last then
                last = key
                LocalPlayer.state:set('multiInvPose', p, true)
            end
        end
    end
end)

-- ------------------------------------------------------------
-- search
-- ------------------------------------------------------------
local function closestPlayer(maxD)
    local me = PlayerPedId()
    local mc = GetEntityCoords(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - mc)
                if d <= maxD and (not bestD or d < bestD) then best, bestD = pid, d end
            end
        end
    end
    return best and GetPlayerServerId(best) or nil
end

function InvSecondaryClient.searchClosest()
    local target = closestPlayer((tonumber(scfg().maxDistance) or 2.0) + 0.5)
    CreateThread(function()
        -- the server words a refusal itself (notify)
        InvClient.request('search', { target = target })
    end)
    return target ~= nil
end

if type(scfg().command) == 'string' and scfg().command ~= '' then
    RegisterCommand(scfg().command, function()
        if InvClient.isOpen() then return end
        InvSecondaryClient.searchClosest()
    end, false)
end

-- ------------------------------------------------------------
-- saddlebags
-- ------------------------------------------------------------
local function mountNetId()
    local ped = PlayerPedId()
    local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped, Citizen.ResultAsInteger()) -- GET_MOUNT
    if (not mount or mount == 0) and sbcfg().useLastMount ~= false then
        local last = Citizen.InvokeNative(0x4C8B59171957BCF7, ped, Citizen.ResultAsInteger()) -- GET_LAST_MOUNT
        if last and last ~= 0 and DoesEntityExist(last)
            and #(GetEntityCoords(last) - GetEntityCoords(ped)) <= (tonumber(sbcfg().lastMountRadius) or 4.0) then
            mount = last
        end
    end
    if mount and mount ~= 0 and DoesEntityExist(mount) and NetworkGetEntityIsNetworked(mount) then
        return NetworkGetNetworkIdFromEntity(mount)
    end
    return nil
end

local function saddleOpen(netId)
    if sbcfg().enabled == false then return false end
    netId = netId or mountNetId()
    if not netId then
        local m = Config.Secondary and Config.Secondary.messages and Config.Secondary.messages.no_mount
        if m then TriggerEvent('MULTIinventory:cl:notify', { text = m, type = 'error' }) end
        return false
    end
    -- RINGOstables handles this (own horse + distance) and opens the bags by bagId
    TriggerServerEvent('vorp_inventory:Server:SaddleOpen', netId)
    return true
end

-- the UI's saddlebag button calls this hook (client/nui.lua)
InvClient.saddlebag = saddleOpen
InvSecondaryClient.saddleOpen = saddleOpen

AddEventHandler('MULTIinventory:client:openSaddlebag', function() saddleOpen() end)

exports('SearchClosestPlayer', function() return InvSecondaryClient.searchClosest() end)
exports('OpenSaddlebag', function() return saddleOpen() end)
exports('GetPose', function() return InvSecondaryClient.pose() end)
