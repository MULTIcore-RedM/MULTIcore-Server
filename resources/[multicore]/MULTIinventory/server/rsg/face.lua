-- ============================================================
-- MULTIinventory :: the rsg-inventory face (server)
-- Answers exports['rsg-inventory']:* with rsg-inventory's argument and
-- return shapes, adds RSG's Player.Functions item methods, and handles the
-- server events RSG's UI and scripts use.
--
-- Shapes and behaviour follow RSG v2's rsg-inventory server/exports.lua and
-- server/events (GPL v3, Copyright the RSG / Rexshack-RedM team), adapted
-- to MULTIinventory's engine. See CREDITS.md.
--
-- Ids: a number is a player's server id; 'otherplayer-<id>' too; 'drop-<n>'
-- is drop:<n>; any other name is a stash (engine id 'stash:<name>', saved
-- under <name> in `inventories`, exactly like rsg-inventory).
-- ============================================================

local Inv = MULTIInv
local Rsg = {}
MULTIInv.Rsg = Rsg

-- ------------------------------------------------------------
-- export aliasing: exports['rsg-inventory']:X() reaches these
-- (the runtime looks exports up through '__cfx_export_<resource>_<name>')
-- ------------------------------------------------------------
local function export(name, fn)
    Rsg[name] = fn
    AddEventHandler(('__cfx_export_rsg-inventory_%s'):format(name), function(setCB) setCB(fn) end)
end

local KNOWN = { player = true, stash = true, glovebox = true, trunk = true, custom = true, drop = true }

--- Engine id for an RSG stash / drop name.
function Rsg.StashId(identifier)
    if type(identifier) ~= 'string' then return nil end
    local t = identifier:match('^(%a+):')
    if t and KNOWN[t] then return identifier end
    local n = identifier:match('^drop%-(%d+)$')
    if n then return 'drop:' .. n end
    return 'stash:' .. identifier
end

--- inventory, playerSrc for an RSG identifier (player id or inventory name).
function Rsg.Resolve(identifier, create)
    local src = tonumber(identifier)
    if type(identifier) == 'string' then
        local o = identifier:match('^otherplayer%-(%d+)$')
        src = o and tonumber(o) or nil
        if not src then
            local id = Rsg.StashId(identifier)
            local inv = create and Inv.Get(id) or Inv.Exists(id)
            return inv, nil
        end
    end
    if not src then return nil end
    local id = Inv.PlayerInv(src)
    local inv = id and Inv.List[id]
    if inv and not inv.ownerSrc then inv = nil end
    return inv, inv and src or nil
end

local function copy(v) return Inv.DeepCopy(v) end

-- ------------------------------------------------------------
-- satchel load / save (called by the core)
-- ------------------------------------------------------------

export('LoadInventory', function(source, citizenid)
    return Inv.LoadPlayer(tonumber(source), citizenid)
end)

export('SaveInventory', function(source, offline)
    if offline then
        local pd = source
        if type(pd) ~= 'table' or not pd.citizenid then return end
        local live = Inv.List['player:' .. pd.citizenid]
        if live and live.ownerSrc then return Inv.Save(live) end
        local data = json.encode(Inv.Compact(Inv.NormalizeItems(pd.items)))
        if data == '{}' then data = '[]' end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { data, pd.citizenid })
        return
    end
    local src = tonumber(source)
    local id = src and Inv.BySrc[src]
    if id and Inv.List[id] then return Inv.Save(Inv.List[id]) end
    local P = src and Inv.GetPlayer(src)
    if P then
        local data = json.encode(Inv.Compact(Inv.NormalizeItems(P.PlayerData.items)))
        if data == '{}' then data = '[]' end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { data, P.PlayerData.citizenid })
    end
end)

-- ------------------------------------------------------------
-- items
-- ------------------------------------------------------------

export('AddItem', function(identifier, item, amount, slot, info, reason, noForceDrop)
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not Inv.IsPositiveInt(amount) then return false end
    local inv, src = Rsg.Resolve(identifier, true)
    if not inv then return false end
    if slot == false then slot = nil end
    if type(info) ~= 'table' then info = nil end
    local ok, err = Inv.AddTo(inv, item, amount, info, slot, reason)
    if ok then return true end
    if src and Config.ForceDropWhenFull and not noForceDrop and (err == 'too_heavy' or err == 'no_space' or err == 'limit') then
        if Inv.ForceDrop(src, item, amount, info, reason) then return true, 'dropped' end
    end
    return false
end)

export('RemoveItem', function(identifier, item, amount, slot, reason, isMove)
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not Inv.IsPositiveInt(amount) then return false end
    local inv, src = Rsg.Resolve(identifier)
    if not inv then return false end
    if slot == false then slot = nil end
    local ok, _, info = Inv.RemoveFrom(inv, item, amount, slot, nil, reason)
    if not ok then return false end
    if src then
        local def = Inv.Items[item:lower()]
        if def and def.type == 'weapon' and isMove then
            TriggerClientEvent('MULTIinventory:client:weaponRemoved', src, item:lower(), info and info.serie)
        end
        TriggerEvent('rsg-inventory:server:itemRemovedFromPlayerInventory', src, item:lower(),
            { amount = amount, slot = tonumber(slot) or 'Multiple', info = info }, reason, isMove)
    end
    return true
end)

export('SetInventory', function(source, items)
    local inv = Rsg.Resolve(source)
    if not inv or type(items) ~= 'table' then return end
    Inv.SetItems(inv, items, 'SetInventory')
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue',
        ('**%s (citizenid: %s | id: %s)** items set'):format(GetPlayerName(source) or '?', inv.citizenid or '?', tostring(source)))
end)

export('SetItemData', function(source, itemName, key, val, slot)
    if not itemName or not key then return false end
    local inv = Rsg.Resolve(source)
    if not inv then return false end
    local s
    if tonumber(slot) then
        s = inv.items[tonumber(slot)]
        if s and s.name ~= itemName:lower() then s = nil end
    else
        s = Inv.FindItems(inv.id, itemName)[1]
    end
    if not s then return false end
    if key == 'amount' then
        local n = Inv.Amount(val)
        if not n then return false end
        s.amount = n
    elseif key == 'info' then
        s.info = type(val) == 'table' and copy(val) or {}
    elseif key == 'name' or key == 'slot' then
        return false
    else
        s[key] = val
    end
    Inv.Changed(inv, { action = 'info', name = s.name, amount = 0, slot = s.slot, reason = 'SetItemData' })
    return true
end)

export('GetItemWeight', function(itemName)
    local def = Inv.GetItemDef(itemName)
    return def and def.weight or nil
end)

export('UseItem', function(a, ...)
    -- RSG: UseItem(itemName, ...) passes ... to the callback. The core calls UseItem(source, itemName).
    if type(a) == 'number' then
        local item = ...
        local name = type(item) == 'table' and item.name or item
        local stack = type(item) == 'table' and item or nil
        return Inv.UseByName(a, name, stack)
    end
    local cb = Inv.RsgUsable(a)
    if cb then return cb(...) end
    local src, stack = ...
    if tonumber(src) then return Inv.UseByName(tonumber(src), a, type(stack) == 'table' and stack or nil) end
end)

export('GetSlotsByItem', function(items, itemName)
    local found = {}
    if type(items) ~= 'table' or type(itemName) ~= 'string' then return found end
    for slot, item in pairs(items) do
        if type(item) == 'table' and item.name and item.name:lower() == itemName:lower() then found[#found + 1] = slot end
    end
    return found
end)

export('GetFirstSlotByItem', function(items, itemName)
    if type(items) ~= 'table' or type(itemName) ~= 'string' then return nil end
    local best
    for slot, item in pairs(items) do
        if type(item) == 'table' and item.name and item.name:lower() == itemName:lower() then
            local n = tonumber(slot)
            if n and (not best or n < best) then best = n end
        end
    end
    return best
end)

export('GetTotalWeight', function(items)
    if type(items) ~= 'table' then return 0 end
    local w = 0
    for _, item in pairs(items) do
        if type(item) == 'table' then
            local def = item.name and Inv.Items[item.name:lower()]
            w = w + (tonumber(item.weight) or (def and def.weight) or 0) * (tonumber(item.amount) or 0)
        end
    end
    return w
end)

export('GetItemBySlot', function(source, slot)
    local inv = Rsg.Resolve(source)
    if not inv or not tonumber(slot) then return nil end
    Inv.CheckDecay(inv)
    return inv.items[tonumber(slot)]
end)

export('GetItemByName', function(source, item)
    local inv = Rsg.Resolve(source)
    if not inv or item == nil then return nil end
    return Inv.FindItems(inv.id, tostring(item))[1]
end)

export('GetItemsByName', function(source, item)
    local inv = Rsg.Resolve(source)
    if not inv or item == nil then return nil end
    return Inv.FindItems(inv.id, tostring(item))
end)

export('GetSlots', function(identifier)
    local inv = Rsg.Resolve(identifier)
    if not inv then return 0, 0 end
    local used = Inv.UsedSlots(inv)
    return used, inv.slots - used
end)

export('GetItemCount', function(source, items)
    local inv = Rsg.Resolve(source)
    if not inv then return nil end
    if type(items) == 'table' then
        local n = 0
        for _, name in pairs(items) do if type(name) == 'string' then n = n + Inv.Count(inv.id, name) end end
        return n
    end
    if type(items) ~= 'string' then return 0 end
    return Inv.Count(inv.id, items)
end)

export('CanAddItem', function(source, item, amount)
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or amount <= 0 then return false end
    if not Inv.GetItemDef(item) then return false end
    local inv = Rsg.Resolve(source)
    if not inv then return true end   -- rsg-inventory: unknown inventory = nothing stops it
    local ok, err = Inv.CanAddTo(inv, item, amount)
    if ok then return true end
    if err == 'too_heavy' then return false, 'weight' end
    if err == 'no_space' then return false, 'slots' end
    return false, err
end)

export('GetFreeWeight', function(source)
    if not source then return 0 end
    local inv = Rsg.Resolve(source)
    if not inv then return 0 end
    return inv.maxWeight - Inv.Weight(inv)
end)

export('ClearInventory', function(source, filterItems)
    local inv, src = Rsg.Resolve(source)
    if not inv then return end
    Inv.Clear(inv, filterItems, 'ClearInventory')
    if src then
        TriggerClientEvent('MULTIinventory:client:unequipAll', src)
        TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red',
            ('**%s (citizenid: %s | id: %s)** inventory cleared'):format(GetPlayerName(src) or '?', inv.citizenid or '?', src))
    end
end)

export('HasItem', function(source, items, amount)
    local inv = Rsg.Resolve(source)
    if not inv then return false end
    Inv.CheckDecay(inv)
    if type(items) == 'string' then
        local need = tonumber(amount)
        for _, s in pairs(inv.items) do
            if s.name == items:lower() and (not need or s.amount >= need) then return true end
        end
        -- also true when the total over several stacks is enough
        return need ~= nil and Inv.Count(inv.id, items) >= need
    end
    if type(items) ~= 'table' then return false end
    local isArray = table.type(items) == 'array'
    for k, v in pairs(items) do
        local name = isArray and v or k
        local need = isArray and (tonumber(amount) or 1) or (tonumber(v) or 1)
        if type(name) ~= 'string' or Inv.Count(inv.id, name) < need then return false end
    end
    return true
end)

-- ------------------------------------------------------------
-- open / close / stashes
-- ------------------------------------------------------------

export('OpenInventory', function(source, identifier, data)
    local src = tonumber(source)
    if not src then return end
    if not identifier then return Inv.Open(src) end
    if type(identifier) ~= 'string' then return end
    data = type(data) == 'table' and data or nil
    local spec = data and { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight, coords = data.coords } or nil
    return Inv.Open(src, Rsg.StashId(identifier), spec)
end)

export('OpenInventoryById', function(source, targetId)
    return Inv.OpenPlayer(tonumber(source), tonumber(targetId))
end)

export('CloseInventory', function(source, identifier)
    Inv.Close(tonumber(source))
    TriggerClientEvent('rsg-inventory:client:closeInv', tonumber(source))
end)

export('ClearStash', function(identifier)
    local inv = Inv.Exists(Rsg.StashId(identifier) or '')
    if not inv then return end
    inv.items = {}
    Inv.Changed(inv, { action = 'set', reason = 'ClearStash' })
    Inv.Save(inv)
end)

export('SaveStash', function(identifier)
    local inv = Inv.Exists(Rsg.StashId(identifier) or '')
    if inv then Inv.Save(inv) end
end)

--- rsg-inventory's GetInventory: { items, isOpen, label, maxweight, slots, coords } or nil.
export('GetInventory', function(identifier)
    local inv = Rsg.Resolve(identifier)
    if not inv then return nil end
    Inv.CheckDecay(inv)
    return { items = inv.items, isOpen = inv.isOpen, label = inv.label, maxweight = inv.maxWeight, slots = inv.slots, coords = inv.coords }
end)

export('GetStashItems', function(identifier)
    local inv = Inv.Exists(Rsg.StashId(identifier) or '')
    return inv and inv.items or {}
end)

local function createInventory(identifier, data)
    local id = Rsg.StashId(identifier)
    if not id then return end
    data = type(data) == 'table' and data or {}
    local spec = { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight, coords = data.coords }
    if Inv.Exists(id) then Inv.Configure(id, spec) else Inv.Create(id, spec) end
end
export('CreateInventory', createInventory)
export('RegisterStash', createInventory)

export('DeleteInventory', function(identifier)
    local id = Rsg.StashId(identifier)
    return id and Inv.Delete(id) or false
end)
export('RemoveInventory', function(identifier)
    local id = Rsg.StashId(identifier)
    return id and Inv.Delete(id) or false
end)

export('ForceDropItem', function(source, item, amount, info, reason)
    return Inv.ForceDrop(tonumber(source), item, tonumber(amount) or 1, info, reason)
end)

-- ------------------------------------------------------------
-- shops: they live in their own resource, MULTIstores. rsg-inventory's shop
-- exports are passed on to it with the same arguments; without MULTIstores
-- they print one warning and return false.
-- ------------------------------------------------------------

local STORES = 'MULTIstores'
local warnedNoStores = {}
local function stores(fn)
    if GetResourceState(STORES) == 'started' then return exports[STORES] end
    if not warnedNoStores[fn] then
        warnedNoStores[fn] = true
        print(('^3[MULTIinventory] rsg-inventory %s was called by %s, but shops are in MULTIstores, which is not started (ensure MULTIstores after MULTIinventory)^7')
            :format(fn, tostring(GetInvokingResource())))
    end
    return nil
end

export('CreateShop', function(shopData)
    local S = stores('CreateShop')
    if not S then return false end
    return S:CreateShop(shopData)
end)
export('OpenShop', function(source, name)
    local S = stores('OpenShop')
    if not S then return false end
    return S:OpenShop(tonumber(source), name)
end)
export('DoesShopExist', function(name)
    local S = stores('DoesShopExist')
    if not S then return false end
    return S:DoesShopExist(name)
end)
export('RestockShop', function(name, percentage)
    local S = stores('RestockShop')
    if not S then return false end
    return S:RestockShop(name, percentage)
end)

-- ------------------------------------------------------------
-- usables
-- ------------------------------------------------------------

local function createUsable(name, cb)
    local res = GetInvokingResource()
    return Inv.RegisterUsable(name, function(src, stack) return cb(src, stack) end, { face = 'rsg', resource = res })
end
export('CreateUseableItem', createUsable)
export('CreateUsableItem', createUsable)

-- ------------------------------------------------------------
-- Player.Functions item methods (RSG scripts call Player.Functions.AddItem ...)
-- ------------------------------------------------------------

local function registerPlayerMethods(src)
    local methods = {
        AddItem        = function(item, amount, slot, info, reason) return Rsg.AddItem(src, item, amount, slot, info, reason) end,
        RemoveItem     = function(item, amount, slot, reason) return Rsg.RemoveItem(src, item, amount, slot, reason) end,
        GetItemBySlot  = function(slot) return Rsg.GetItemBySlot(src, slot) end,
        GetItemByName  = function(item) return Rsg.GetItemByName(src, item) end,
        GetItemsByName = function(item) return Rsg.GetItemsByName(src, item) end,
        ClearInventory = function(filterItems) return Rsg.ClearInventory(src, filterItems) end,
        SetInventory   = function(items) return Rsg.SetInventory(src, items) end,
        HasItem        = function(items, amount) return Rsg.HasItem(src, items, amount) end,
    }
    local core = Inv.Core()
    for name, fn in pairs(methods) do
        pcall(core.Functions.AddPlayerMethod, src, name, fn)
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then registerPlayerMethods(Player.PlayerData.source) end
end)

AddEventHandler('MULTIinventory:ready', function()
    local ok, players = pcall(Inv.Core().Functions.GetRSGPlayers)
    if ok and type(players) == 'table' then
        for src in pairs(players) do
            registerPlayerMethods(tonumber(src))
            pcall(function() Player(tonumber(src)).state.inv_busy = false end)
        end
    end
end)

-- ------------------------------------------------------------
-- events RSG's UI and scripts send
-- ------------------------------------------------------------

RegisterNetEvent('rsg-inventory:server:closeInventory', function(_)
    Inv.Close(source, true)
    pcall(function() Player(source).state.inv_busy = false end)
end)

RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = source
    if type(item) ~= 'table' or Inv.RateLimited(src, 'use') then
        if Config.DebugUse then print(('[MULTIinventory use] %s: dropped (bad data or too fast)'):format(src)) end
        return
    end
    local ok, err = Inv.WithLock(src, Inv.Use, src, tonumber(item.slot))
    if Config.DebugUse then
        print(('[MULTIinventory use] %s: slot %s (%s) -> %s %s, handlers: %d'):format(src, tostring(item.slot), tostring(item.name),
            tostring(ok), tostring(err or ''), #(Inv.Usables[tostring(item.name):lower()] or {})))
    end
end)

-- TEMPORARY (Config.DebugUse): the client says why a use stopped before reaching the server
RegisterNetEvent('MULTIinventory:server:useTrace', function(slot, why, name)
    if not Config.DebugUse then return end
    print(('[MULTIinventory use] %s (client): slot %s %s - %s'):format(source, tostring(slot), tostring(name or ''), tostring(why):sub(1, 200)))
end)

local function rsgInvToEngine(src, name)
    if name == 'player' then return Inv.PlayerInv(src) end
    if type(name) ~= 'string' then return nil end
    local o = name:match('^otherplayer%-(%d+)$')
    if o then return Inv.PlayerInv(tonumber(o)) end
    if name:find('^shop%-') then return nil end -- stores are MULTIstores' own screen
    return Rsg.StashId(name)
end

RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    local src = source
    if Inv.RateLimited(src, 'move') then return end
    local f, t = rsgInvToEngine(src, fromInventory), rsgInvToEngine(src, toInventory)
    if not f or not t then return end
    Inv.Move(src, f, fromSlot, t, toSlot, tonumber(toAmount) or tonumber(fromAmount))
end)

-- RSG's search rule: dead players by anyone, handcuffed ones by the law (from rsg-inventory)
RegisterNetEvent('rsg-inventory:server:openPlayerInventory', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    local P, T = Inv.GetPlayer(src), targetId and Inv.GetPlayer(targetId)
    if not P or not T or targetId == src then return end
    local a, b = Inv.PlayerCoords(src), Inv.PlayerCoords(targetId)
    if not a or not b or #(a - b) > 3.0 then return Inv.Notify(src, 'too_far', 'error') end
    local meta = T.PlayerData.metadata or {}
    local job = P.PlayerData.job and P.PlayerData.job.name
    local law = job == 'police' or job == 'marshal' or job == 'sheriff' or Inv.IsAdmin(src)
    if not meta.isdead and not (meta.ishandcuffed and law) then return Inv.Notify(src, 'no_permission', 'error') end
    Inv.OpenPlayer(src, targetId)
end)

lib.callback.register('rsg-inventory:server:giveItem', function(src, target, item, amount, slot)
    if Inv.RateLimited(src, 'give') then return false end
    local inv = Inv.List[Inv.PlayerInv(src) or '']
    local s = inv and tonumber(slot) and inv.items[tonumber(slot)]
    if not s or type(item) ~= 'string' or s.name ~= item:lower() then return false end
    return Inv.WithLock(src, Inv.Give, src, target, slot, amount) == true
end)

lib.callback.register('rsg-inventory:server:getPlayerName', function(src, target)
    local a, b = Inv.PlayerCoords(src), tonumber(target) and Inv.PlayerCoords(tonumber(target))
    if not a or not b or #(a - b) > 10.0 then return nil end
    local T = Inv.GetPlayer(tonumber(target))
    local ci = T and T.PlayerData.charinfo
    if ci and ci.firstname then return ci.firstname .. ' ' .. (ci.lastname or '') end
    return GetPlayerName(target)
end)
