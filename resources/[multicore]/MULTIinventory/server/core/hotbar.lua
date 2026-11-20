-- ============================================================
-- MULTIinventory :: server/core/hotbar.lua
--
-- Hotbar data model: Config.Player.hotbarSlots (5) references per character,
-- persisted in multiinv_hotbar. A reference points at a stack id (items) or a
-- weapon id; when that stack is gone the next stack of the same item is used.
--
--   Hotbar.load(charId) / Hotbar.unload(charId)            (yields on load)
--   Hotbar.get(charId) -> { [n] = { kind, ref, item } }
--   Hotbar.view(charId) -> { { slot, kind, ref, item, label, count }, ... }
--   Hotbar.assign(src, n, fromSlot) -> ok, err              fromSlot = player grid slot
--   Hotbar.clear(src, n) -> ok
--   Hotbar.resolve(charId, n) -> container, entry|nil
--   Hotbar.use(src, n) -> ok, err                           items: Usables.use; weapons: hook hotbarWeapon
-- ============================================================

Hotbar = Hotbar or {}

local bars = {}

local function size() return Config.Player.hotbarSlots or 5 end

function Hotbar.load(charId)
    local bar = {}
    for _, r in ipairs(InvDB.query('SELECT * FROM `multiinv_hotbar` WHERE `charid` = ?', { charId })) do
        local n = tonumber(r.slot)
        if n and n >= 1 and n <= size() then
            bar[n] = { kind = r.ref_kind, ref = math.tointeger(tonumber(r.ref_id)), item = r.item }
        end
    end
    bars[charId] = bar
    return bar
end

function Hotbar.unload(charId) bars[charId] = nil end
function Hotbar.get(charId) return bars[charId] or {} end

local function save(charId)
    local bar = bars[charId] or {}
    local list = { { query = 'DELETE FROM `multiinv_hotbar` WHERE `charid` = ?', values = { charId } } }
    for n = 1, size() do
        local h = bar[n]
        if h then
            local vals = {}
            local ph = InvDB.bind({ charId, n, h.kind, h.ref, h.item }, 5, vals)
            list[#list + 1] = { query = 'INSERT INTO `multiinv_hotbar` (`charid`,`slot`,`ref_kind`,`ref_id`,`item`) VALUES ' .. ph, values = vals }
        end
    end
    CreateThread(function() InvDB.transaction(list) end)
end

function Hotbar.resolve(charId, n)
    local h = (bars[charId] or {})[n]
    local c = Containers.peek('player:' .. charId)
    if not h or not c then return c, nil end
    if h.kind == 'weapon' then
        for _, e in pairs(c.stacks) do
            if e.kind == 'weapon' and e.weaponId == h.ref then return c, e end
        end
        return c, nil
    end
    for _, e in pairs(c.stacks) do
        if e.id == h.ref then return c, e end
    end
    if h.item then
        local list = Stacking.candidates(c, h.item, nil)
        return c, list[1]
    end
    return c, nil
end

function Hotbar.view(charId)
    local out = {}
    for n = 1, size() do
        local h = (bars[charId] or {})[n]
        if h then
            local c, e = Hotbar.resolve(charId, n)
            local count = 0
            if h.kind == 'weapon' then count = e and 1 or 0
            elseif c and h.item then count = Stacking.count(c, h.item, nil) end
            local d = h.item and Registry.get(h.item)
            out[#out + 1] = { slot = n, kind = h.kind, ref = h.ref, item = h.item,
                              label = (e and e.metadata and e.metadata.label) or (d and d.label) or h.item, count = count }
        end
    end
    return out
end

local function push(src, charId)
    TriggerClientEvent('MULTIinventory:cl:hotbar', src, Hotbar.view(charId))
end

function Hotbar.assign(src, n, fromSlot)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    n = Util.toInt(n)
    if not n or n < 1 or n > size() then return false, 'bad_slot' end
    local c = Containers.peek('player:' .. st.charId)
    local e = c and c.stacks[Util.toInt(fromSlot) or -1]
    if not e then return false, 'no_item' end
    if e.kind ~= 'weapon' then
        local d = Registry.get(e.item)
        if d and d.hotbar == false then return false, 'not_hotbar' end
    end
    bars[st.charId] = bars[st.charId] or {}
    -- one reference per thing: remove it from other hotbar slots
    for k, h in pairs(bars[st.charId]) do
        if (e.kind == 'weapon' and h.kind == 'weapon' and h.ref == e.weaponId) or (e.kind ~= 'weapon' and h.ref == e.id) then
            bars[st.charId][k] = nil
        end
    end
    if e.kind == 'weapon' then
        bars[st.charId][n] = { kind = 'weapon', ref = e.weaponId, item = e.item }
    else
        bars[st.charId][n] = { kind = 'item', ref = e.id, item = e.item }
    end
    save(st.charId)
    push(src, st.charId)
    return true
end

function Hotbar.clear(src, n)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    n = Util.toInt(n)
    if bars[st.charId] and n then bars[st.charId][n] = nil end
    save(st.charId)
    push(src, st.charId)
    return true
end

-- per-player throttle for hotbar keys (on top of the Actions rate limit): stops key-repeat spam
-- from toggling a weapon in and out of the hand every frame.
local lastUse = {}
AddEventHandler('playerDropped', function() lastUse[source] = nil end)

function Hotbar.use(src, n)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    n = Util.toInt(n)                                   -- nil for NaN / inf / fractions / junk
    if not n or n < 1 or n > size() then return false, 'bad_slot' end
    local now = GetGameTimer()
    local gap = tonumber(Config.Player.hotbarServerGapMs) or 250
    if lastUse[src] and now - lastUse[src] >= 0 and now - lastUse[src] < gap then return false, 'hotbar_busy' end
    lastUse[src] = now
    -- ownership + slot re-checked here: resolve only looks at this character's own player container
    local c, e = Hotbar.resolve(st.charId, n)
    if not e then return false, 'no_item' end
    if e.kind == 'weapon' then
        if not InvHooks.has('hotbarWeapon') then return false, 'not_usable' end
        InvHooks.emit('hotbarWeapon', src, e.weaponId, e)
        return true
    end
    local ok, err = Usables.use(src, c.id, e.slot, { src = src, reason = 'use' })
    if ok then
        local h = bars[st.charId][n]
        -- follow the stack actually used (the referenced one may be gone)
        if h and h.ref ~= e.id and c.stacks[e.slot] == e then h.ref = e.id; save(st.charId) end
        push(src, st.charId)
    end
    return ok, err
end
