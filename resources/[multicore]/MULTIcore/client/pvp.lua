-- Keeps players hostile to each other while PVP is enabled.
-- Briefly switches to "respect" after pressing E (interact) / F so greeting or
-- interacting with another player doesn't start a fight, and while mounted/in a vehicle.

local RELATIONSHIP_HOSTILE = 3
local RELATIONSHIP_FRIENDLY = 1
local INTERACT_GRACE_MS = 3500

local keyE = RSGShared.Keybinds['E']
local keyF = RSGShared.Keybinds['F']

-- Runs in MULTIcore's one frame thread (client/prompts.lua). The relationship and the friendly-fire
-- option are only sent to the game when they change, plus once every REAPPLY_MS in case another
-- script changed them.
local REAPPLY_MS = 3000
local PLAYER = `PLAYER`
local friendlyUntil, lastRel, lastApply, offAt = 0, nil, -1000000, -1000000

MULTIFrame.add(function(now)
    if not RSGCore.Config.Server.PVP then
        if now - offAt >= 1000 then
            offAt = now
            SetRelationshipBetweenGroups(RELATIONSHIP_FRIENDLY, PLAYER, PLAYER)
            lastRel = nil
        end
        return
    end
    if IsControlJustPressed(0, keyE) or IsControlJustPressed(0, keyF) then
        friendlyUntil = now + INTERACT_GRACE_MS
    end

    local friendly = now < friendlyUntil or IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped, false)
    local rel = friendly and RELATIONSHIP_FRIENDLY or RELATIONSHIP_HOSTILE
    if rel ~= lastRel or now - lastApply >= REAPPLY_MS then
        lastRel, lastApply = rel, now
        SetRelationshipBetweenGroups(rel, PLAYER, PLAYER)
        Citizen.InvokeNative(0xF808475FA571D823, true) -- NetworkSetFriendlyFireOption
    end
end)
