-- ============================================================
-- MULTIinventory :: server/core/actions.lua
--
-- Player actions from the client/NUI. Server-authoritative and rate limited.
-- Transport: client -> TriggerServerEvent('MULTIinventory:sv:action', reqId, name, data)
--            server -> TriggerClientEvent('MULTIinventory:cl:result', src, reqId, ok, errOrResult)
-- (client/main.lua: InvClient.request(name, data) wraps this; the UI's
--  NUI callbacks call it and answer the NUI with { ok, err, data }).
--
-- Container references in data: 'player' | 'equip' | 'secondary' | a full container id the
-- player may access (own player/equip, the open secondary).
--
-- Built-in actions (data fields):
--   open      {}                                   player inventory (secondary: secondary part / State.open)
--   close     {}
--   move      { from = { container, slot }, to = { container, slot|nil }, count|nil }
--   split     { container, slot, count, toSlot|nil }
--   merge     { container, fromSlot, toSlot }       (same as move onto an equal stack)
--   sort      { container, mode = 'name'|'type'|'weight' }
--   use       { slot }                              player grid
--   give      { slot, count|nil, target = serverId }
--   nearby    {}                                    -> { { id, name, distance } } for the give picker
--   drop      { slot, count|nil }                   Config.Drop.mode 'world' (pile) or 'delete' (destroy)
--   pickup    { dropId, slot|nil, count|nil }
--   hotbar    { op = 'assign'|'clear'|'use', n, slot }
-- Other parts add actions with Actions.register(name, fn(src, data) -> ok, err|result)
-- (e.g. clothing: equip/unequip; weapons: equipWeapon; secondary: openStash).
-- ============================================================

Actions = Actions or {}

local handlers = {}
local buckets = {}   -- [src] = { second, n }

function Actions.register(name, fn) handlers[name] = fn end
function Actions.has(name) return handlers[name] ~= nil end

local function rateOk(src)
    local sec = Util.now()
    local b = buckets[src]
    if not b or b[1] ~= sec then b = { sec, 0 }; buckets[src] = b end
    b[2] = b[2] + 1
    return b[2] <= (Config.Actions.ratePerSecond or 15)
end

---Resolve a container reference for `src`; enforces access.
function Actions.ref(src, ref)
    local st = State.get(src)
    if not st then return nil, 'player_not_loaded' end
    local id
    if ref == nil or ref == 'player' then id = 'player:' .. st.charId
    elseif ref == 'equip' or ref == 'equipment' then id = 'equip:' .. st.charId
    elseif ref == 'secondary' then id = State.secondaryOf(src)
    else id = tostring(ref) end
    if not id then return nil, 'no_secondary' end
    if not State.canAccess(src, id) then return nil, 'no_access' end
    -- worn clothing of someone else is never reachable from a session, admin excepted
    if Containers.kindOf(id) == 'equip' and id ~= 'equip:' .. st.charId and not State.isAdminSession(src) then
        local allow = Config.Secondary and Config.Secondary.search and Config.Secondary.search.allowClothing
        if not allow then return nil, 'no_access' end
    end
    local c = Containers.peek(id) or Containers.get(id)
    if not c then return nil, 'unknown_container' end
    return c
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local v = GetEntityCoords(ped)
    return { x = v.x, y = v.y, z = v.z }
end

local function distance(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ------------------------------------------------------------
-- built-ins
-- ------------------------------------------------------------
handlers.open = function(src) return State.open(src, nil) end
handlers.close = function(src) return State.close(src, false) end

handlers.move = function(src, d)
    local from, to = d.from or {}, d.to or {}
    local fc, err = Actions.ref(src, from.container)
    if not fc then return false, err end
    local tc
    tc, err = Actions.ref(src, to.container)
    if not tc then return false, err end
    return Inv.move(fc, Util.toInt(from.slot) or -1, tc, to.slot, d.count, { src = src, reason = 'move', from = fc.id, to = tc.id })
end

handlers.split = function(src, d)
    local c, err = Actions.ref(src, d.container)
    if not c then return false, err end
    local slot = Util.toInt(d.slot) or -1
    local e = c.stacks[slot]
    if not e then return false, 'no_item' end
    local n = Util.toInt(d.count) or math.floor(e.count / 2)
    if n < 1 or n >= e.count then return false, 'bad_count' end
    local toSlot = d.toSlot or Containers.freeSlot(c)
    if not toSlot then return false, 'slots' end
    if c.stacks[toSlot] then return false, 'slot_taken' end
    return Inv.move(c, slot, c, toSlot, n, { src = src, reason = 'split', from = c.id, to = c.id })
end

handlers.merge = function(src, d)
    local c, err = Actions.ref(src, d.container)
    if not c then return false, err end
    local a, b = c.stacks[Util.toInt(d.fromSlot) or -1], c.stacks[Util.toInt(d.toSlot) or -1]
    if not a or not b then return false, 'no_item' end
    if a == b or not Stacking.compatible(b, a.key, a.decayAt) then return false, 'not_stackable' end
    return Inv.move(c, a.slot, c, b.slot, nil, { src = src, reason = 'merge', from = c.id, to = c.id })
end

handlers.sort = function(src, d)
    local c, err = Actions.ref(src, d.container)
    if not c then return false, err end
    return Stacking.sort(c, d.mode)
end

handlers.use = function(src, d)
    local st = State.get(src)
    return Usables.use(src, 'player:' .. st.charId, Util.toInt(d.slot) or -1, { src = src, reason = 'use' })
end

handlers.nearby = function(src)
    local me = pedCoords(src)
    local out = {}
    for tsrc, tst in pairs(State.all()) do
        if tsrc ~= src then
            local dd = distance(me, pedCoords(tsrc))
            if dd <= Config.Give.maxDistance then
                out[#out + 1] = { id = tsrc, name = tst.name or ('#' .. tsrc), distance = Util.round(dd, 1) }
            end
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return true, out
end

handlers.give = function(src, d)
    local st = State.get(src)
    local tgt = Util.toInt(d.target)
    if not tgt or tgt == src then return false, 'bad_target' end
    local tst = State.get(tgt)
    if not tst then return false, 'target_not_loaded' end
    if distance(pedCoords(src), pedCoords(tgt)) > Config.Give.maxDistance then return false, 'too_far' end
    local pc = Containers.peek('player:' .. st.charId)
    local e = pc and pc.stacks[Util.toInt(d.slot) or -1]
    if not e then return false, 'no_item' end
    if e.kind ~= 'weapon' and Inv.def(e.item).canRemove == false then return false, 'cannot_give' end
    local tc = Containers.get('player:' .. tst.charId, { create = true })
    local count = d.count == nil and e.count or Util.toInt(d.count)
    if not count or count < 1 or count > e.count then return false, 'bad_count' end
    local snapshot = e.kind == 'weapon' and { kind = 'weapon', weaponId = e.weaponId, item = e.item, count = 1 }
        or { item = e.item, count = count, metadata = Util.deepcopy(e.metadata) }
    local ok, err = Inv.move(pc, e.slot, tc, nil, count, { src = src, reason = 'give', from = pc.id, to = tc.id, target = tgt })
    if not ok then
        if err == 'weight' or err == 'slots' or err == 'limit' then Sync.notify(tgt, L('inv_full'), 'error') end
        return false, err
    end
    local label = (snapshot.metadata and snapshot.metadata.label) or Inv.def(snapshot.item).label
    Sync.notify(src, L('inv_given', { label = label, count = count }), 'success')
    Sync.notify(tgt, L('inv_received', { label = label, count = count }), 'success')
    InvLog.write('give', { actorSrc = src, targetCharId = tst.charId, from = pc.id, to = tc.id, item = snapshot.item,
                           count = count, data = { stacks = { snapshot } } })
    TriggerEvent('MULTIinventory:itemGiven', src, tgt, snapshot)
    return true
end

handlers.drop = function(src, d)
    if Config.Drop.mode == 'world' then
        return Drops.dropFromPlayer(src, d.slot, d.count)
    end
    return Drops.destroyFromPlayer(src, d.slot, d.count)
end

handlers.pickup = function(src, d)
    return Drops.pickup(src, d.dropId, d.slot, d.count)
end

handlers.hotbar = function(src, d)
    if d.op == 'assign' then return Hotbar.assign(src, d.n, d.slot) end
    if d.op == 'clear' then return Hotbar.clear(src, d.n) end
    if d.op == 'use' then return Hotbar.use(src, d.n) end
    return false, 'bad_op'
end

-- ------------------------------------------------------------
-- dispatcher
-- ------------------------------------------------------------
function Actions.run(src, name, data)
    if type(name) ~= 'string' or not handlers[name] then return false, 'unknown_action' end
    if not rateOk(src) then return false, 'rate_limited' end
    if not State.get(src) then return false, 'player_not_loaded' end
    if type(data) ~= 'table' then data = {} end
    local ok, a, b = pcall(handlers[name], src, data)
    if not ok then
        print(('^1[MULTIinventory] action %s from %s failed: %s^7'):format(name, tostring(src), tostring(a)))
        return false, 'server_error'
    end
    if a and b == nil then return true end
    return a and true or false, b
end

RegisterNetEvent('MULTIinventory:sv:action', function(reqId, name, data)
    local src = source
    CreateThread(function()
        local ok, res = Actions.run(src, name, data)
        if not ok and type(res) == 'string' and src then
            -- player-facing message for the common refusals
            local msg = ({ weight = L('inv_full'), limit = L('inv_full'), slots = L('inv_no_slot'), locked = L('secondary_locked') })[res]
            -- item use: say why it was refused instead of doing nothing (and log it for the owner)
            if not msg and (name == 'use' or (name == 'hotbar' and type(data) == 'table' and data.op == 'use')) then
                msg = ({
                    not_usable = 'This item has no use.', expired = 'This has gone off.', broken = 'This is broken.',
                    cooldown = 'Wait a moment before using something else.', no_item = 'That item is gone.',
                    handler_error = 'Something went wrong using that item.', player_not_loaded = 'Your character is still loading.',
                    rate_limited = 'Slow down.',
                })[res]
                if name == 'hotbar' then
                    if res == 'not_usable' then msg = "That can't be used." end
                    if res == 'no_item' then msg = 'Nothing on that hotbar slot.' end
                end
                local slotItem
                pcall(function()
                    local st = State.get(src)
                    local c = st and Containers.peek('player:' .. st.charId)
                    local e = c and c.stacks[Util.toInt(data and data.slot) or -1]
                    slotItem = e and e.item
                end)
                print(('[MULTIinventory] use refused for %s: %s (item %s)'):format(tostring(src), tostring(res), tostring(slotItem)))
            end
            if msg then Sync.notify(src, msg, 'error') end
        end
        TriggerClientEvent('MULTIinventory:cl:result', src, reqId, ok, res)
    end)
end)

AddEventHandler('playerDropped', function() buckets[source] = nil end)
