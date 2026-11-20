-- ============================================================
-- MULTIserver :: connect handler: whitelist, then the queue
-- Queue (Config.Queue.Enabled, off by default): when every slot is
-- taken, joining players wait in the deferral screen. Higher
-- priority (ACE multiserver.priority.N) goes first, then who came
-- first. A player who dropped within GraceMinutes goes to the front.
-- MULTIadmin's ban check is its own playerConnecting handler and
-- refuses banned players by itself; this file never looks at bans.
-- ============================================================

local Q = Config.Queue
Queue = {}

local waiting = {}     -- entries { src, license, name, priority, since, seq }
local admitted = {}    -- license -> time the slot is held until (let in, not arrived yet)
local dropped = {}     -- license -> os.time() of the drop (grace)
local seq = 0

-- ---------------------------------------------------------------
-- pure helpers (tested by the self-test)
-- ---------------------------------------------------------------

--- Sorted copy: priority high to low, then earliest arrival, then arrival order.
function Queue.Order(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e end
    table.sort(out, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        if a.since ~= b.since then return a.since < b.since end
        return a.seq < b.seq
    end)
    return out
end

--- Priority of a joining player: grace first, else the highest ACE level, else 0.
function Queue.Priority(src, license, now)
    now = now or os.time()
    local d = license and dropped[license]
    if d and now - d <= Q.GraceMinutes * 60 then return Q.GracePriority, true end
    if src then
        for level = Q.MaxPriority, 1, -1 do
            if IsPlayerAceAllowed(src, ('%s.%d'):format(Q.PriorityAce, level)) then return level, false end
        end
    end
    return 0, false
end

function Queue.MarkDropped(license, at) if license then dropped[license] = at or os.time() end end

-- ---------------------------------------------------------------
-- slots
-- ---------------------------------------------------------------

local function maxSlots()
    if Q.MaxPlayers and Q.MaxPlayers > 0 then return Q.MaxPlayers end
    return GetConvarInt('sv_maxclients', 32)
end

local function usedSlots()
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        if tonumber(id) and tonumber(id) < 65535 then n = n + 1 end   -- players still connecting have temporary ids
    end
    local now = os.time()
    for lic, untilT in pairs(admitted) do
        if untilT < now then admitted[lic] = nil else n = n + 1 end
    end
    return n
end

function Queue.FreeSlots() return maxSlots() - usedSlots() end

local function removeEntry(entry)
    for i, e in ipairs(waiting) do
        if e == entry then table.remove(waiting, i) return end
    end
end

local function card(pos, total, priority)
    return json.encode({
        type = 'AdaptiveCard', version = '1.0',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        body = {
            { type = 'TextBlock', text = _L('queue_title'), size = 'Large', weight = 'Bolder', horizontalAlignment = 'Center' },
            { type = 'TextBlock', text = _L('queue_position', pos, total), size = 'Medium', horizontalAlignment = 'Center' },
            { type = 'TextBlock', text = priority > 0 and _L('queue_priority', priority) or _L('queue_wait'), isSubtle = true, horizontalAlignment = 'Center', wrap = true },
        },
    })
end

--- Holds the deferral until a slot is free and it is this player's turn. true = let in, false = left.
function Queue.Wait(src, deferrals)
    local license = GetPlayerIdentifierByType(src, 'license') or ('src:' .. tostring(src))
    for i = #waiting, 1, -1 do   -- same licence reconnecting: the old place is given up
        if waiting[i].license == license then table.remove(waiting, i) end
    end
    local priority, grace = Queue.Priority(src, license)
    seq = seq + 1
    local entry = { src = src, license = license, name = GetPlayerName(src) or '?', priority = priority, since = os.time(), seq = seq }
    waiting[#waiting + 1] = entry
    MS.Debug('queue: %s joins with priority %d%s', entry.name, priority, grace and ' (grace)' or '')
    while true do
        if not GetPlayerEndpoint(src) then
            removeEntry(entry)
            return false
        end
        local order = Queue.Order(waiting)
        local pos = 1
        for i, e in ipairs(order) do if e == entry then pos = i break end end
        if pos == 1 and Queue.FreeSlots() > 0 then
            removeEntry(entry)
            admitted[license] = os.time() + Q.JoinTimeoutSec
            dropped[license] = nil
            MS.Debug('queue: %s let in', entry.name)
            return true
        end
        if Q.Card then
            deferrals.presentCard(card(pos, #order, priority))
        else
            deferrals.update(_L('queue_text', pos, #order) .. (priority > 0 and ('  ' .. _L('queue_priority', priority)) or ''))
        end
        Wait(Q.UpdateMs)
    end
end

-- arrival frees the held slot; a drop starts the grace time
AddEventHandler('playerJoining', function()
    local lic = GetPlayerIdentifierByType(source, 'license')
    if lic then admitted[lic] = nil end
end)

AddEventHandler('playerDropped', function()
    if not Q.Enabled then return end
    Queue.MarkDropped(GetPlayerIdentifierByType(source, 'license'))
end)

-- ---------------------------------------------------------------
-- the connect handler
-- ---------------------------------------------------------------

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not Config.Whitelist.Enabled and not Q.Enabled then return end
    local src = source
    deferrals.defer()
    Wait(0)
    if Config.Whitelist.Enabled then
        deferrals.update(_L('wl_checking'))
        local ok, msg = Whitelist.Check(src)
        if not ok then return deferrals.done(msg) end
    end
    if Q.Enabled then
        deferrals.update(_L('queue_checking'))
        if not Queue.Wait(src, deferrals) then return end
    end
    deferrals.done()
end)

exports('GetQueueLength', function() return #waiting end)

if MS.testMode then
    exports('_TestQueue', function(cmd, a, b, c)
        if cmd == 'order' then
            local out = {}
            for i, e in ipairs(Queue.Order(a)) do out[i] = e.key end
            return out
        elseif cmd == 'priority' then return Queue.Priority(a, b, c)
        elseif cmd == 'dropped' then Queue.MarkDropped(a, b) return true
        end
    end)
end
