-- ============================================================
-- MULTIinventory :: server/admin/admin.lua
--
-- Admin tools (ace Config.Admin.ace, or the server console). Every action is
-- written to multiinv_log as admin_<action> (always on).
--
--   /invinspect <target>                  open target as the secondary panel (console: print)
--   /invgive    <target> <item> <count> [json metadata]
--   /invremove  <target> <item> <count>
--   /invclear   <target>                  grid only (worn clothing untouched)
--   /invstash   <containerId>             open any container (stash, saddlebag, drop:<n>...)
--   /invlog     <charId|containerId> [n]  print recent log rows
--   /invrestore <logId> [target]          re-create the stacks recorded in a log row
--   /invreload                            reload item definitions from `items`
--   /invflush                             save everything now
-- <target> = server id | player:<charid> | <container id>
--
-- Admin.* functions are the same operations for scripts (RINGOadminmenu):
--   Admin.give(actorSrc, target, item, count, meta)  Admin.remove(...)  Admin.clear(actorSrc, target)
--   Admin.restore(actorSrc, logId, target|nil)       Admin.inspect(actorSrc, target)
-- ============================================================

Admin = Admin or {}

local function allowed(src)
    return src == 0 or IsPlayerAceAllowed(src, Config.Admin.ace)
end

local function reply(src, msg)
    if src == 0 then print('[MULTIinventory] ' .. msg) else Sync.notify(src, msg, 'inform') end
end

---'12' (online server id) -> 'player:<charid>'; 'player:5' / any id -> as is.
function Admin.targetId(t)
    if t == nil then return nil end
    local n = tonumber(t)
    if n and tostring(t):match('^%d+$') then
        local st = State.get(n)
        return st and ('player:' .. st.charId) or nil, st and st.charId
    end
    local cid = tostring(t):match('^player:(%d+)$') or tostring(t):match('^equip:(%d+)$')
    return tostring(t), tonumber(cid)
end

local function charOfContainer(id)
    return tonumber(tostring(id):match('^%a+:(%d+)$'))
end

function Admin.give(actor, target, item, count, meta)
    local id, cid = Admin.targetId(target)
    if not id then return false, 'unknown_target' end
    local ok, res = Inv.add(id, item, tonumber(count), meta, { src = actor, reason = 'admin' })
    if ok then
        InvLog.write('admin_give', { actorSrc = actor, targetCharId = cid, to = id, item = item, count = tonumber(count),
                                     data = { stacks = { { item = item, count = tonumber(count), metadata = Meta.normalize(meta) } } } })
    end
    return ok, res
end

function Admin.remove(actor, target, item, count)
    local id, cid = Admin.targetId(target)
    if not id then return false, 'unknown_target' end
    local ok, res = Inv.remove(id, item, tonumber(count), nil, { src = actor, reason = 'admin' })
    if ok then
        InvLog.write('admin_remove', { actorSrc = actor, targetCharId = cid, from = id, item = item, count = tonumber(count),
                                       data = { stacks = res } })
    end
    return ok, res
end

function Admin.clear(actor, target)
    local id, cid = Admin.targetId(target)
    if not id then return false, 'unknown_target' end
    local ok, removed = Inv.clear(id, {}, { src = actor, reason = 'admin' })
    if ok then
        InvLog.write('admin_clear', { actorSrc = actor, targetCharId = cid, from = id, count = #removed, data = { stacks = removed } })
    end
    return ok, removed
end

function Admin.inspect(actor, target)
    local id, cid = Admin.targetId(target)
    if not id then return false, 'unknown_target' end
    InvLog.write('admin_inspect', { actorSrc = actor, targetCharId = cid, from = id })
    if actor == 0 then
        local stacks = Inv.getStacks(id)
        local load, cap = Inv.weight(id)
        print(('[MULTIinventory] %s  %.2f / %s kg  %d stacks'):format(id, load, tostring(cap), #stacks))
        for _, s in ipairs(stacks) do
            print(('  [%2d] #%s %s x%d %s'):format(s.slot, tostring(s.id), s.name, s.count, Util.jsonEncode(s.metadata)))
        end
        return true
    end
    if not State.get(actor) then return false, 'player_not_loaded' end
    return State.open(actor, id, { admin = true, label = id })
end

function Admin.restore(actor, logId, target)
    local rows = InvLog.recent({ id = tonumber(logId) }, 1)
    local r = rows[1]
    if not r then return false, 'no_log_row' end
    local data = Util.jsonDecode(r.data, {}) or {}
    local stacks = data.stacks or data.removed
    if type(stacks) ~= 'table' or #stacks == 0 then return false, 'nothing_to_restore' end
    local id = target and Admin.targetId(target) or r.container_from
    if not id then return false, 'unknown_target' end
    local done, failed = 0, {}
    for _, s in ipairs(stacks) do
        if s.kind == 'weapon' then
            failed[#failed + 1] = 'weapon ' .. tostring(s.weaponId) .. ' (weapons part)'
        else
            local ok, err = Inv.add(id, s.item, s.count, s.metadata, { src = actor, reason = 'admin' }, { decayAt = s.decayAt })
            if ok then done = done + 1 else failed[#failed + 1] = ('%s x%d: %s'):format(s.item, s.count, tostring(err)) end
        end
    end
    InvLog.write('admin_restore', { actorSrc = actor, targetCharId = charOfContainer(id), to = id,
                                    data = { logId = tonumber(logId), restored = done, failed = failed } })
    return done > 0, { restored = done, failed = failed }
end

local function cmd(key, fn)
    local name = Config.Admin.commands[key]
    if not name then return end
    RegisterCommand(name, function(src, args)
        if not allowed(src) then reply(src, 'No permission.') return end
        CreateThread(function()
            local ok, err = pcall(fn, src, args)
            if not ok then reply(src, 'Error: ' .. tostring(err)) end
        end)
    end, false)
end

cmd('inspect', function(src, a)
    local ok, err = Admin.inspect(src, a[1])
    if not ok then reply(src, 'inspect failed: ' .. tostring(err)) end
end)

cmd('give', function(src, a)
    local meta = a[4] and Util.jsonDecode(table.concat(a, ' ', 4), nil) or nil
    local ok, err = Admin.give(src, a[1], a[2], tonumber(a[3]) or 1, meta)
    reply(src, ok and ('gave %s x%s to %s'):format(a[2], a[3] or 1, a[1]) or ('give failed: ' .. tostring(err)))
end)

cmd('remove', function(src, a)
    local ok, err = Admin.remove(src, a[1], a[2], tonumber(a[3]) or 1)
    reply(src, ok and ('removed %s x%s from %s'):format(a[2], a[3] or 1, a[1]) or ('remove failed: ' .. tostring(err)))
end)

cmd('clear', function(src, a)
    local ok, res = Admin.clear(src, a[1])
    reply(src, ok and ('cleared %s (%d stacks, logged)'):format(a[1], #res) or ('clear failed: ' .. tostring(res)))
end)

cmd('stash', function(src, a)
    if src == 0 then return Admin.inspect(0, a[1]) end
    local ok, err = Admin.inspect(src, a[1])
    if not ok then reply(src, 'open failed: ' .. tostring(err)) end
end)

cmd('log', function(src, a)
    local id, cid = Admin.targetId(a[1])
    local rows = InvLog.recent({ charId = cid }, tonumber(a[2]) or 15)
    InvLog.write('admin_log', { actorSrc = src, targetCharId = cid, from = id })
    for _, r in ipairs(rows) do
        reply(src, ('#%s %s %s %s->%s %s x%s by %s'):format(r.id, os.date('%Y-%m-%d %H:%M', tonumber(r.at) or 0), r.action,
            tostring(r.container_from), tostring(r.container_to), tostring(r.item), tostring(r.count), tostring(r.actor)))
    end
end)

cmd('restore', function(src, a)
    local ok, res = Admin.restore(src, a[1], a[2])
    if ok then reply(src, ('restored %d stack(s); failed: %d'):format(res.restored, #res.failed))
    else reply(src, 'restore failed: ' .. tostring(type(res) == 'table' and Util.jsonEncode(res) or res)) end
end)

cmd('reload', function(src)
    local n = Registry.reload()
    InvLog.write('admin_reload', { actorSrc = src, count = n })
    reply(src, ('item registry reloaded: %d items'):format(n))
end)

cmd('flush', function(src)
    local ok = Persistence.flush()
    InvLog.flush()
    InvLog.write('admin_flush', { actorSrc = src })
    reply(src, ok and 'saved' or 'save failed (see console)')
end)
