-- ============================================================
-- MULTIinventory :: what the satchel UI sends (server side of docs/INVENTORY_CLIENT.md)
-- Every request is checked here: access, distance, amounts, item kinds.
-- Also: ammo boxes / arrow bundles in a satchel turn into round items, so the
-- server counts rounds and a half-used box can never be lost on reconnect.
-- ============================================================

local Inv = MULTIInv

local function own(src)
    local id = Inv.PlayerInv(src)
    return id and Inv.List[id]
end

local function blocked(src)
    local P = Inv.GetPlayer(src)
    if not P then return true end
    local m = P.PlayerData.metadata or {}
    return m.isdead or m.ishandcuffed or false
end

-- ------------------------------------------------------------
-- open / refresh / close
-- ------------------------------------------------------------

RegisterNetEvent('MULTIinventory:server:openSelf', function()
    local src = source
    if blocked(src) then return end
    Inv.Open(src)
end)

--- Open the satchel next to invId: a drop or stash in reach, or a searchable player.
RegisterNetEvent('MULTIinventory:server:openInventory', function(invId)
    local src = source
    if type(invId) ~= 'string' or #invId > 120 or blocked(src) then return end
    -- inventories only their own script may open (e.g. MULTIbank's safe-deposit boxes)
    for _, prefix in ipairs(Config.ServerOpenOnly or {}) do
        if invId:sub(1, #prefix) == prefix or ('stash:' .. invId):sub(1, #prefix) == prefix then
            return Inv.Notify(src, 'no_permission', 'error')
        end
    end
    local t = Inv.TypeOf(invId)
    if t == 'drop' then
        local inv = Inv.List[invId]
        if not inv then return end
        if not Inv.InReach(src, inv, Config.MaxDistance) then return Inv.Notify(src, 'too_far', 'error') end
        return Inv.Open(src, invId)
    end
    if t == 'player' then
        local inv = Inv.List[invId]
        if not inv or not inv.ownerSrc or inv.ownerSrc == src then return Inv.Open(src) end
        -- RSG's rule: dead players by anyone, handcuffed ones by the law
        local T, P = Inv.GetPlayer(inv.ownerSrc), Inv.GetPlayer(src)
        local meta = T and T.PlayerData.metadata or {}
        local job = P and P.PlayerData.job and P.PlayerData.job.name
        local law = job == 'police' or job == 'marshal' or job == 'sheriff' or Inv.IsAdmin(src)
        if not Inv.InReach(src, inv, 3.0) then return Inv.Notify(src, 'too_far', 'error') end
        if not meta.isdead and not (meta.ishandcuffed and law) then return Inv.Notify(src, 'no_permission', 'error') end
        return Inv.OpenPlayer(src, inv.ownerSrc)
    end
    -- stash-type: RSG lets a client open any stash that is not restricted; ours must also be in reach
    local id = invId:find(':') and invId or ('stash:' .. invId)
    if not Inv.HasStashAccess(src, id) then return Inv.Notify(src, 'no_permission', 'error') end
    local inv = Inv.List[id]
    if inv and not Inv.InReach(src, inv) then return Inv.Notify(src, 'too_far', 'error') end
    Inv.Open(src, id)
end)

RegisterNetEvent('MULTIinventory:server:refresh', function()
    local src = source
    if Inv.RateLimited(src, 'refresh') then return end
    local inv = own(src)
    if inv then Inv.SendUpdate(src, inv) end
end)

RegisterNetEvent('MULTIinventory:server:close', function(_)
    local src = source
    Inv.Close(src, true)
    pcall(function() Player(src).state.inv_busy = false end)
end)

-- ------------------------------------------------------------
-- move / give (callbacks: ok, err)
-- ------------------------------------------------------------

lib.callback.register('MULTIinventory:server:move', function(src, fromId, fromSlot, toId, toSlot, amount)
    if Inv.RateLimited(src, 'move') then return false, 'busy' end
    return Inv.Move(src, fromId, fromSlot, toId, toSlot, amount)
end)

lib.callback.register('MULTIinventory:server:give', function(src, target, slot, amount)
    if Inv.RateLimited(src, 'give') then return false, 'busy' end
    return Inv.WithLock(src, Inv.Give, src, target, slot, amount)
end)

-- ------------------------------------------------------------
-- ammo and throws used on the ped
-- ------------------------------------------------------------

local function isAmmoItem(name)
    local def = Inv.Items[name]
    return def and (Inv.AmmoItems[name] ~= nil or def.type == 'ammo')
end

local function isThrown(name)
    local w = MULTIInvData.Weapons[name]
    return w and w.thrown
end

local function takeUsed(src, list, accept, reason)
    if type(list) ~= 'table' then return end
    local inv = own(src)
    if not inv then return end
    Inv.Batch(function()
        local n = 0
        for name, used in pairs(list) do
            n = n + 1
            if n > 64 then break end
            used = math.floor(tonumber(used) or 0)
            if type(name) == 'string' and used > 0 and accept(name) then
                local have = Inv.Count(inv.id, name)
                local take = math.min(used, have)
                if take > 0 then Inv.RemoveFrom(inv, name, take, nil, nil, reason) end
            end
        end
    end)
end

RegisterNetEvent('MULTIinventory:server:ammoUsed', function(list)
    takeUsed(source, list, isAmmoItem, 'ammo used')
end)

RegisterNetEvent('MULTIinventory:server:thrown', function(list)
    takeUsed(source, list, isThrown, 'thrown')
end)

--- Loaded rounds per weapon: { { id = info.id | info.serie, slot, ammo, ammoType }, ... } -> info.ammo / info.ammoType
RegisterNetEvent('MULTIinventory:server:weaponAmmo', function(list)
    local src = source
    if type(list) ~= 'table' or Inv.RateLimited(src, 'weaponAmmo') then return end
    local inv = own(src)
    if not inv then return end
    Inv.Batch(function()
        for i, e in ipairs(list) do
            if i > 16 then break end
            if type(e) == 'table' then
                local s = tonumber(e.slot) and inv.items[tonumber(e.slot)]
                local function matches(st)
                    return st and st.info and (tostring(st.info.id) == tostring(e.id) or st.info.serie == e.id)
                end
                if not matches(s) then
                    s = nil
                    for _, st in pairs(inv.items) do if matches(st) then s = st break end end
                end
                local w = s and MULTIInvData.Weapons[s.name]
                local ammo = math.floor(tonumber(e.ammo) or -1)
                local t = type(e.ammoType) == 'string' and e.ammoType:upper() or nil
                local okType = t == nil
                if w and t then for _, a in ipairs(w.ammoTypes) do if a == t then okType = true break end end end
                local max = t and MULTIInvData.Ammo[t] and MULTIInvData.Ammo[t].max or 500
                if w and okType and ammo >= 0 and ammo <= max and (s.info.ammo ~= ammo or s.info.ammoType ~= t) then
                    s.info.ammo = ammo
                    s.info.ammoType = t
                    Inv.Changed(inv, { action = 'info', name = s.name, amount = 0, slot = s.slot, reason = 'weapon ammo' })
                end
            end
        end
    end)
end)

-- ------------------------------------------------------------
-- boxes and bundles -> rounds (server counts rounds)
-- ------------------------------------------------------------

local function boxesToRounds()
    if not Config.Ammo.BoxesToRounds then return false end
    return GetResourceState('rsg-ammo') ~= 'started'
end

local converting = {}

--- Opens every ammo box / bundle in a player's satchel into round items while they fit.
function Inv.ConvertAmmoBoxes(inv)
    if not inv or inv.type ~= 'player' or converting[inv.id] or not boxesToRounds() then return end
    converting[inv.id] = true
    Inv.Batch(function()
        local todo = {}
        for slot, s in pairs(inv.items) do
            local box = MULTIInvData.AmmoBoxes[s.name]
            if box then todo[#todo + 1] = { slot = slot, name = s.name, count = s.amount, box = box } end
        end
        for _, t in ipairs(todo) do
            local box, slot = t.box, t.slot
            local ammo = MULTIInvData.Ammo[box.ammo]
            if ammo and ammo.item ~= t.name then
                local name, count = t.name, t.count
                for _ = 1, count do
                    if not Inv.RemoveFrom(inv, name, 1, slot, nil, 'opened into rounds') then break end
                    if not Inv.AddTo(inv, ammo.item, box.rounds, nil, nil, 'opened into rounds') then
                        Inv.AddTo(inv, name, 1, nil, slot, 'rollback')
                        break
                    end
                end
            end
        end
    end)
    converting[inv.id] = nil
end

-- a box or bundle came into a satchel (not a rollback): open it on the next tick
local queued = {}
AddEventHandler('MULTIinventory:changed', function(invId, changes)
    if queued[invId] or not boxesToRounds() or Inv.TypeOf(invId) ~= 'player' then return end
    for _, c in ipairs(changes or {}) do
        if c.action == 'add' and c.reason ~= 'rollback' and MULTIInvData.AmmoBoxes[c.name] then
            queued[invId] = true
            SetTimeout(0, function()
                queued[invId] = nil
                Inv.ConvertAmmoBoxes(Inv.List[invId])
            end)
            return
        end
    end
end)

AddEventHandler('MULTIinventory:playerLoaded', function(_, invId)
    Inv.ConvertAmmoBoxes(Inv.List[invId])
end)
