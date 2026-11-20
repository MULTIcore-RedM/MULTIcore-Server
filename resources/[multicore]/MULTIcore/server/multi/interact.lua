-- ============================================================
-- MULTIcore :: /mcinteract (server)
-- Prints what each MULTI script placed in the world for one player:
-- interaction mode, MULTItarget targets, hold-key prompts and NPCs.
-- The numbers come from the player's client and are only printed;
-- nothing is changed. One report per player every few seconds.
-- GPL v3, part of MULTIcore.
-- ============================================================

local COOLDOWN_MS = 5000        -- least time between two reports from one player
local MAX_LINES = 64            -- most script lines printed per report
local lastAt = {}

local function clean(v, max)
    v = tostring(v or '')
    v = v:gsub('[^%w_%-%.]', '')
    return v:sub(1, max or 32)
end

local function num(v)
    v = math.tointeger(tonumber(v) or 0) or 0
    if v < 0 then v = 0 end
    if v > 99999 then v = 99999 end
    return v
end

RegisterNetEvent('MULTIcore:server:interactReport', function(data)
    local src = source
    local now = GetGameTimer()
    if lastAt[src] and now - lastAt[src] < COOLDOWN_MS then return end
    lastAt[src] = now
    if type(data) ~= 'table' or type(data.list) ~= 'table' then return end

    local who = ('%s [%d]'):format(clean(GetPlayerName(src), 48), src)
    print(('[MULTIcore interact] %s: MULTItarget=%s loggedIn=%s scripts=%d'):format(
        who, clean(data.oxTarget, 16), data.loggedIn == true and 'yes' or 'no', #data.list))
    for i, s in ipairs(data.list) do
        if i > MAX_LINES then break end
        if type(s) == 'table' then
            print(('[MULTIcore interact] %s %-16s mode=%-7s targets=%-4d prompts=%-4d npcs=%d'):format(
                who, clean(s.resource), clean(s.mode, 10), num(s.targets), num(s.prompts), num(s.npcs)))
        end
    end
end)

AddEventHandler('playerDropped', function() lastAt[source] = nil end)
