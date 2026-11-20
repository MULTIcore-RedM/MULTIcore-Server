-- ============================================================
-- MULTIstores :: store engine (server)
-- GPL v3, part of MULTIcore.
--
-- A store is a list of items with prices and stock, kept here (not in the
-- inventory). Every purchase and sale is checked on the server: the store
-- must be open for that player, the player must stand at the counter
-- (OneSync), the stock, the money and the room in the satchel are checked
-- through MULTIinventory (CanAdd / AddItem / RemoveItem) and money moves
-- through MULTIcore (Player.Functions.AddMoney / RemoveMoney).
-- The item shape follows rsg-inventory's CreateShop (RSG v2, GPL v3,
-- by the RSG / Rexshack-RedM team, see CREDITS.md).
-- ============================================================

MS = MS or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

MS.Stores = {}          -- name -> store
MS.Sessions = {}        -- src -> store name the player has open
MS.ready = false        -- true once MULTIinventory is ready and the config stores are built

local busy = {}
local calls = {}
local pending = {}      -- store definitions made before MULTIinventory was ready
local restockedAt = {}  -- store name -> os.time() of its last restock (from multistores_restock)
local savedStock = {}   -- store name -> { [item] = stock } (from multistores_stock)
local dbReady = false

local function dbg(...)
    if Config.Debug then print('[MULTIstores]', ...) end
end
local function warn(msg) print(('^3[MULTIstores] %s^7'):format(msg)) end

local function round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end
local function money(n) return ('%s%.2f'):format(Config.CurrencySign or '$', n or 0) end
MS.Round2 = round2

local function posInt(v, max)
    v = tonumber(v)
    if not v or v ~= v or v < 1 or v ~= math.floor(v) then return nil end
    if max and v > max then return nil end
    return v
end

-- ------------------------------------------------------------
-- tables
-- ------------------------------------------------------------
local function loadDb()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multistores_stock` (
          `store` VARCHAR(100) NOT NULL,
          `item` VARCHAR(100) NOT NULL,
          `stock` INT NOT NULL DEFAULT 0,
          PRIMARY KEY (`store`, `item`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multistores_restock` (
          `store` VARCHAR(100) NOT NULL,
          `restocked_at` INT UNSIGNED NOT NULL DEFAULT 0,
          PRIMARY KEY (`store`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    for _, r in ipairs(MySQL.query.await('SELECT `store`, `item`, `stock` FROM `multistores_stock`') or {}) do
        savedStock[r.store] = savedStock[r.store] or {}
        savedStock[r.store][r.item] = tonumber(r.stock)
    end
    for _, r in ipairs(MySQL.query.await('SELECT `store`, `restocked_at` FROM `multistores_restock`') or {}) do
        restockedAt[r.store] = tonumber(r.restocked_at)
    end
    dbReady = true
end

local function saveStock(store, entry)
    if not store.persistent or entry.amount == nil then return end
    savedStock[store.name] = savedStock[store.name] or {}
    savedStock[store.name][entry.name] = entry.amount
    MySQL.prepare('INSERT INTO `multistores_stock` (`store`, `item`, `stock`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `stock` = VALUES(`stock`)',
        { store.name, entry.name, entry.amount })
end

local function saveRestock(store)
    restockedAt[store.name] = store.restockedAt
    if not store.persistent then return end
    MySQL.prepare('INSERT INTO `multistores_restock` (`store`, `restocked_at`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `restocked_at` = VALUES(`restocked_at`)',
        { store.name, store.restockedAt })
end

-- ------------------------------------------------------------
-- items
-- ------------------------------------------------------------
local WEAPON_CAT = {
    revolver = 'revolvers', pistol = 'pistols', repeater = 'repeaters', rifle = 'rifles', sniper = 'rifles',
    varmint = 'rifles', shotgun = 'shotguns', bow = 'bows', melee = 'melee', thrown = 'thrown',
    lasso = 'tools', held = 'tools', fishing = 'fishing',
}
local ITEM_CAT = {
    consumable = 'food', ingredient = 'food', tools = 'tools', medical = 'medicine', herbalist = 'medicine',
    horse = 'horse', fishing = 'fishing', ammo = 'ammo', weapons = 'melee',
}

local weaponData
local function weaponOf(name)
    if not weaponData then weaponData = MI:GetWeaponData() or {} end
    return weaponData[name]
end
MS.WeaponOf = weaponOf

local function categoryOf(def, given)
    if type(given) == 'string' and given ~= '' then return given end
    local w = weaponOf(def.name)
    if w then return WEAPON_CAT[w.group] or 'goods' end
    if def.type == 'ammo' or tostring(def.name):find('^ammo_') then return 'ammo' end
    return ITEM_CAT[def.category] or 'goods'
end

--- One store entry from an rsg-inventory-shaped item, or nil (unknown item / bad data).
--- lateList (config stores only): an unknown item is noted there instead of warned about,
--- because another resource may still register it (see Config.LateItemSeconds).
local function makeEntry(storeName, it, idx, lateList)
    if type(it) ~= 'table' or type(it.name) ~= 'string' then
        warn(('store %s: item %s has no name, skipped'):format(storeName, tostring(idx)))
        return nil
    end
    local def = MI:GetItemDef(it.name:lower())
    if not def and lateList then
        lateList[#lateList + 1] = { store = storeName, it = it, idx = idx }
        return nil
    end
    if not def then
        warn(('store %s: item "%s" is not in the item registry, skipped'):format(storeName, it.name))
        return nil
    end
    local price = it.price ~= nil and tonumber(it.price) or nil
    local buyPrice = tonumber(it.buyPrice or it.sellPrice)
    if price and price < 0 then price = nil end
    if buyPrice and buyPrice <= 0 then buyPrice = nil end
    if not price and not buyPrice then
        warn(('store %s: item "%s" has neither price nor buyPrice, skipped'):format(storeName, it.name))
        return nil
    end
    local amount = it.amount ~= nil and math.max(0, math.floor(tonumber(it.amount) or 0)) or nil
    local w = weaponOf(def.name)
    return {
        name = def.name,
        label = (type(it.info) == 'table' and it.info.label) or def.label or def.name,
        description = def.description or def.desc or '',
        image = def.image or (def.name .. '.png'),
        weight = tonumber(def.weight) or 0,
        price = price and round2(price) or nil,
        amount = amount,
        default = amount,
        restock = tonumber(it.restock),
        buyPrice = buyPrice and round2(buyPrice) or nil,
        maxStock = tonumber(it.maxStock),
        minQuality = tonumber(it.minQuality),
        info = type(it.info) == 'table' and it.info or nil,
        category = categoryOf(def, it.category),
        serialWeapon = def.type == 'weapon' and w ~= nil and not w.thrown,
        canRemove = def.canRemove ~= false,
    }
end

-- ------------------------------------------------------------
-- stores
-- ------------------------------------------------------------
--- Adds one made entry to a store (saved stock, buy list, category tab).
local function addEntry(store, e)
    local saved = savedStock[store.name]
    if store.persistent and e.amount ~= nil and saved and saved[e.name] ~= nil then
        e.amount = math.max(0, saved[e.name])
    end
    store.items[#store.items + 1] = e
    e.index = #store.items
    if e.buyPrice and not store.buys[e.name] then store.buys[e.name] = e end
    if e.price then
        for _, c in ipairs(store.categories) do
            if c == e.category then return end
        end
        store.categories[#store.categories + 1] = e.category
    end
end

local function build(def)
    local name = def.name
    local store = {
        name = name,
        label = def.label or name,
        type = def.type,
        kind = def.kind or 'script',
        coords = def.coords and vector3(def.coords.x, def.coords.y, def.coords.z) or nil,
        distance = tonumber(def.distance),
        persistent = def.persistentStock == true,
        jobs = type(def.jobs) == 'table' and def.jobs or nil,
        jobType = def.jobType,
        onDuty = def.onDuty == true,
        hours = def.hours,
        items = {},
        buys = {},
        categories = {},
    }
    for i, it in ipairs(def.items or {}) do
        local e = makeEntry(name, it, i, def.lateList)
        if e then addEntry(store, e) end
    end
    store.restockedAt = restockedAt[name] or os.time()
    if not restockedAt[name] then saveRestock(store) end
    -- viewers of a replaced store keep it open
    local old = MS.Stores[name]
    MS.Stores[name] = store
    if old then
        for src, open in pairs(MS.Sessions) do
            if open == name then MS.PushState(src) end
        end
    end
    dbg(('store %s: %d items, %d bought'):format(name, #store.items, (function() local n = 0 for _ in pairs(store.buys) do n = n + 1 end return n end)()))
    return store
end

--- Creates or replaces a store. → true | false, err
--- def = { name, label, items = { { name, price, amount, buyPrice, maxStock, minQuality, restock, category, info } },
---         coords?, distance?, persistentStock?, jobs?, jobType?, onDuty?, hours?, type? }
function MS.CreateStore(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' or def.name == '' or #def.name > 100 then return false, 'bad_store' end
    if type(def.items) ~= 'table' then return false, 'bad_store' end
    if not MS.ready then
        pending[#pending + 1] = def
        return true
    end
    build(def)
    return true
end

function MS.DoesStoreExist(name)
    if type(name) ~= 'string' then return false end
    if MS.Stores[name] then return true end
    for _, d in ipairs(pending) do if d.name == name then return true end end
    return false
end

function MS.GetStore(name)
    return MS.Stores[name]
end

--- Adds stock to an item (an item that never runs out stays so). → true | false
function MS.AddStock(name, itemName, amount)
    local store = MS.Stores[name]
    amount = math.floor(tonumber(amount) or 0)
    if not store or amount == 0 then return false end
    local done = false
    for _, e in ipairs(store.items) do
        if e.name == itemName then
            if e.amount ~= nil then
                e.amount = math.max(0, e.amount + amount)
                saveStock(store, e)
                MS.StockChanged(store, e)
            end
            done = true
            break
        end
    end
    return done
end

--- Changes an item's price (and optionally what the store pays for it). price nil keeps the price. → true | false
function MS.SetPrice(name, itemName, price, buyPrice)
    local store = MS.Stores[name]
    if not store then return false end
    local done = false
    for _, e in ipairs(store.items) do
        if e.name == itemName then
            if price ~= nil then
                price = tonumber(price)
                if not price or price < 0 then return false end
                e.price = round2(price)
            end
            if buyPrice ~= nil then
                buyPrice = tonumber(buyPrice)
                e.buyPrice = buyPrice and buyPrice > 0 and round2(buyPrice) or nil
                store.buys[e.name] = e.buyPrice and e or nil
            end
            done = true
        end
    end
    if done then
        for src, open in pairs(MS.Sessions) do
            if open == name then MS.PushState(src) end
        end
    end
    return done
end

--- Puts stock back: `percent` of the start amount (default: each item's `restock`, else full).
function MS.Restock(name, percent)
    local store = MS.Stores[name]
    if not store then return false end
    for _, e in ipairs(store.items) do
        if e.default and e.amount ~= nil and e.amount < e.default then
            local step = percent and math.floor(e.default * (tonumber(percent) or 100) / 100 + 0.5) or (e.restock or e.default)
            e.amount = math.min(e.default, e.amount + math.max(0, step))
            saveStock(store, e)
        end
    end
    store.restockedAt = os.time()
    saveRestock(store)
    for src, open in pairs(MS.Sessions) do
        if open == name then MS.PushState(src) end
    end
    return true
end

-- ------------------------------------------------------------
-- checks
-- ------------------------------------------------------------
local function rateLimited(src)
    local now = GetGameTimer()
    local keep = {}
    for _, t in ipairs(calls[src] or {}) do
        if now - t < Config.RateLimit.WindowMs then keep[#keep + 1] = t end
    end
    calls[src] = keep
    if #keep >= Config.RateLimit.Calls then return true end
    keep[#keep + 1] = now
    return false
end
MS.RateLimited = rateLimited

local function nearStore(src, store)
    if not store.coords or not Config.ServerDistanceCheck then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - store.coords) <= (store.distance or Config.MaxUseDistance)
end

local function jobAllowed(P, store)
    if not store.jobs and not store.jobType then return true end
    local job = P.PlayerData.job or {}
    if store.onDuty and not job.onduty then return false end
    if store.jobType and job.type == store.jobType then return true end
    if store.jobs then
        for _, j in ipairs(store.jobs) do if j == job.name then return true end end
    end
    return false
end

local function playerInv(src)
    local ok, id = pcall(function() return MI:PlayerInv(src) end)
    return ok and id or nil
end

-- ------------------------------------------------------------
-- what the screen shows
-- ------------------------------------------------------------
local function catLabel(key)
    local text = _L('cat_' .. key)
    if text == 'cat_' .. key then text = key:gsub('_', ' '):gsub('^%l', string.upper) end
    return text
end

--- The player's stacks this store buys: { slot, name, label, image, amount, price, quality }.
local function sellList(src, store)
    local out = {}
    if not Config.Sell.Enabled or not next(store.buys) then return out end
    local pid = playerInv(src)
    local inv = pid and MI:Get(pid)
    if type(inv) ~= 'table' or type(inv.items) ~= 'table' then return out end
    for slot, s in pairs(inv.items) do
        local e = store.buys[s.name]
        if e and e.canRemove then
            local q = type(s.info) == 'table' and tonumber(s.info.quality) or nil
            local each = e.buyPrice
            if q and Config.Sell.QualityScales then each = round2(each * math.max(0, math.min(100, q)) / 100) end
            out[#out + 1] = {
                slot = tonumber(s.slot) or tonumber(slot), name = s.name, label = (type(s.info) == 'table' and s.info.label) or e.label,
                image = e.image, amount = tonumber(s.amount) or 1, price = each, quality = q,
                tooPoor = (e.minQuality and q and q < e.minQuality) or nil,
            }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

--- Everything the store screen needs for this player.
function MS.State(src, store)
    local P = RSGCore.Functions.GetPlayer(src)
    local cash = P and tonumber(P.Functions.GetMoney(Config.Currency)) or 0
    local items = {}
    for _, e in ipairs(store.items) do
        if e.price then
            items[#items + 1] = {
                i = e.index, name = e.name, label = e.label, desc = e.description, image = e.image,
                price = e.price, stock = e.amount, category = e.category, weight = e.weight,
            }
        end
    end
    local cats = {}
    for _, key in ipairs(store.categories) do cats[#cats + 1] = { key = key, label = catLabel(key) } end
    return {
        name = store.name, label = store.label, typeLabel = store.typeLabel,
        cash = cash, items = items, categories = cats,
        sell = sellList(src, store), buys = next(store.buys) ~= nil and Config.Sell.Enabled,
    }
end

function MS.PushState(src)
    local store = MS.Stores[MS.Sessions[src] or '']
    if store then TriggerClientEvent('MULTIstores:client:state', src, MS.State(src, store)) end
end

--- Tells everyone viewing the store the new stock of one item.
function MS.StockChanged(store, e)
    for src, open in pairs(MS.Sessions) do
        if open == store.name then TriggerClientEvent('MULTIstores:client:stock', src, e.index, e.amount) end
    end
end

-- ------------------------------------------------------------
-- open / close
-- ------------------------------------------------------------

--- Opens a store's screen for a player. → true | false, err
function MS.OpenStore(src, name)
    src = tonumber(src)
    local store = MS.Stores[name or '']
    if not src or not store then return false, 'no_store' end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false, 'no_player' end
    if not jobAllowed(P, store) then return false, 'not_allowed' end
    if not nearStore(src, store) then return false, 'too_far' end
    MS.Sessions[src] = store.name
    TriggerClientEvent('MULTIstores:client:open', src, MS.State(src, store), store.coords, store.distance or Config.MaxUseDistance)
    TriggerEvent('MULTIstores:opened', src, store.name)
    return true
end

function MS.CloseStore(src)
    src = tonumber(src)
    if not src or not MS.Sessions[src] then return false end
    local name = MS.Sessions[src]
    MS.Sessions[src] = nil
    TriggerClientEvent('MULTIstores:client:close', src)
    TriggerEvent('MULTIstores:closed', src, name)
    return true
end

-- ------------------------------------------------------------
-- buy / sell
-- ------------------------------------------------------------
local function openStoreOf(src, name)
    local store = MS.Stores[name or '']
    if not store then return nil, 'no_store' end
    if MS.Sessions[src] ~= store.name then return nil, 'not_open' end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return nil, 'no_player' end
    if not jobAllowed(P, store) then return nil, 'not_allowed' end
    if not nearStore(src, store) then return nil, 'too_far' end
    return store, nil, P
end

local function doBuy(src, name, index, amount)
    local store, err, P = openStoreOf(src, name)
    if not store then return false, err end
    local e = store.items[tonumber(index) or -1]
    if not e or not e.price then return false, 'not_for_sale' end
    amount = posInt(amount, Config.MaxPerPurchase)
    if not amount then return false, 'bad_amount' end
    if e.amount ~= nil and amount > e.amount then return false, 'out_of_stock' end
    local pid = playerInv(src)
    if not pid then return false, 'no_player' end
    local can, cerr = MI:CanAdd(pid, e.name, amount, e.info)
    if not can then return false, cerr or 'no_space' end
    local total = round2(e.price * amount)
    local have = tonumber(P.Functions.GetMoney(Config.Currency)) or 0
    if total > 0 and (have < total or not P.Functions.RemoveMoney(Config.Currency, total, 'store ' .. store.name)) then
        return false, 'no_money'
    end
    local given = 0
    if e.serialWeapon then
        -- one at a time through MULTIinventory's weapon maker: each gets its own serial and id
        for _ = 1, amount do
            local info = MI:WeaponNew(e.name, e.info)
            if not MI:AddItem(pid, e.name, 1, info, nil, 'store ' .. store.name) then break end
            given = given + 1
        end
    else
        if MI:AddItem(pid, e.name, amount, e.info, nil, 'store ' .. store.name) then given = amount end
    end
    if given < amount then
        local back = round2(e.price * (amount - given))
        if back > 0 then P.Functions.AddMoney(Config.Currency, back, 'store refund ' .. store.name) end
        if given == 0 then return false, 'no_space' end
        total = round2(total - back)
    end
    if e.amount ~= nil then
        e.amount = e.amount - given
        saveStock(store, e)
        MS.StockChanged(store, e)
    end
    dbg(('%s bought %dx %s at %s for %s'):format(src, given, e.name, store.name, money(total)))
    TriggerEvent('MULTIstores:bought', src, store.name, e.name, given, total)
    return true, nil, { name = e.name, label = e.label, amount = given, total = total }
end

local function doSell(src, name, slot, amount)
    if not Config.Sell.Enabled then return false, 'not_bought' end
    local store, err, P = openStoreOf(src, name)
    if not store then return false, err end
    local pid = playerInv(src)
    if not pid then return false, 'no_player' end
    slot = posInt(slot)
    local stack = slot and MI:GetSlot(pid, slot)
    if type(stack) ~= 'table' then return false, 'no_item' end
    local e = store.buys[stack.name]
    if not e or not e.canRemove then return false, 'not_bought' end
    amount = posInt(amount, Config.MaxPerPurchase)
    if not amount then return false, 'bad_amount' end
    if amount > (tonumber(stack.amount) or 0) then return false, 'no_item' end
    local q = type(stack.info) == 'table' and tonumber(stack.info.quality) or nil
    if e.minQuality and q and q < e.minQuality then return false, 'quality_low' end
    if e.amount ~= nil and e.maxStock and e.amount + amount > e.maxStock then return false, 'store_full' end
    local each = e.buyPrice
    if q and Config.Sell.QualityScales then each = each * math.max(0, math.min(100, q)) / 100 end
    local total = round2(each * amount)
    if total <= 0 then return false, 'worthless' end
    if not MI:RemoveItem(pid, stack.name, amount, slot, nil, 'sold to ' .. store.name) then return false, 'no_item' end
    P.Functions.AddMoney(Config.Currency, total, 'store ' .. store.name)
    if e.amount ~= nil then
        e.amount = e.amount + amount
        saveStock(store, e)
        MS.StockChanged(store, e)
    end
    dbg(('%s sold %dx %s to %s for %s'):format(src, amount, e.name, store.name, money(total)))
    TriggerEvent('MULTIstores:sold', src, store.name, e.name, amount, total)
    return true, nil, { name = e.name, label = e.label, amount = amount, total = total }
end

local function locked(src, fn, ...)
    if busy[src] then return false, 'busy' end
    busy[src] = true
    local ok, a, b, c = pcall(fn, src, ...)
    busy[src] = nil
    if not ok then
        print(('^1[MULTIstores] %s^7'):format(tostring(a)))
        return false, 'failed'
    end
    return a, b, c
end

--- Buys `amount` of the store's item number `index` for a player who has the store open. → true, nil, info | false, err
function MS.Buy(src, name, index, amount) return locked(tonumber(src), doBuy, name, index, amount) end
--- Sells `amount` from the player's satchel slot to the store the player has open. → true, nil, info | false, err
function MS.Sell(src, name, slot, amount) return locked(tonumber(src), doSell, name, slot, amount) end

-- ------------------------------------------------------------
-- client requests
-- ------------------------------------------------------------
local function notify(src, key, kind, ...)
    exports.MULTIcore:Notify(src, { text = _L(key, ...), title = _L('title'), type = kind or 'info' })
end
MS.Notify = notify

lib.callback.register('MULTIstores:open', function(src, name)
    if type(name) ~= 'string' or rateLimited(src) then return false end
    local store = MS.Stores[name]
    -- only stores with a counter in the world can be opened from the client; scripts open the rest
    if not store or store.kind ~= 'config' then return false, 'no_store' end
    local ok, err = MS.OpenStore(src, name)
    if not ok then notify(src, 'err_' .. tostring(err), 'error') end
    return ok, err
end)

lib.callback.register('MULTIstores:buy', function(src, name, index, amount)
    if rateLimited(src) then return { ok = false, err = 'busy' } end
    local ok, err, info = MS.Buy(src, name, index, amount)
    if ok then
        notify(src, 'bought', 'success', info.amount, info.label, money(info.total))
    else
        notify(src, 'err_' .. tostring(err), 'error')
    end
    local store = MS.Stores[MS.Sessions[src] or '']
    return { ok = ok == true, err = err, state = store and MS.State(src, store) or nil }
end)

lib.callback.register('MULTIstores:sell', function(src, name, slot, amount)
    if rateLimited(src) then return { ok = false, err = 'busy' } end
    local ok, err, info = MS.Sell(src, name, slot, amount)
    if ok then
        notify(src, 'sold', 'money', info.amount, info.label, money(info.total))
    else
        notify(src, 'err_' .. tostring(err), 'error')
    end
    local store = MS.Stores[MS.Sessions[src] or '']
    return { ok = ok == true, err = err, state = store and MS.State(src, store) or nil }
end)

RegisterNetEvent('MULTIstores:server:close', function()
    local src = source
    if MS.Sessions[src] then
        local name = MS.Sessions[src]
        MS.Sessions[src] = nil
        TriggerEvent('MULTIstores:closed', src, name)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    MS.Sessions[src], busy[src], calls[src] = nil, nil, nil
end)

-- ------------------------------------------------------------
-- start-up: config stores, then anything scripts made early
-- ------------------------------------------------------------
local function storeLabel(s)
    local t = Config.Types[s.type] or {}
    if type(s.label) == 'string' and s.label ~= '' then return s.label end
    return _L(t.label or 'type_general', _L('town_' .. tostring(s.town)))
end

--- Gunsmith list: every weapon in MULTIinventory's weapon data, every ammo box, the extras.
function MS.GunsmithItems()
    local G = Config.Gunsmith or {}
    local list, names = {}, {}
    for name in pairs(MI:GetWeaponData() or {}) do names[#names + 1] = name end
    table.sort(names)
    local order = { revolver = 1, pistol = 2, repeater = 3, rifle = 4, varmint = 4, sniper = 5, shotgun = 6, bow = 7, melee = 8, thrown = 9, lasso = 10, held = 10, fishing = 10 }
    table.sort(names, function(a, b)
        local wa, wb = weaponOf(a), weaponOf(b)
        local oa, ob = order[wa.group] or 99, order[wb.group] or 99
        if oa ~= ob then return oa < ob end
        local pa = tonumber((G.Weapons or {})[a]) or 0
        local pb = tonumber((G.Weapons or {})[b]) or 0
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    for _, name in ipairs(names) do
        local w = weaponOf(name)
        local price = (G.Weapons or {})[name]
        if price == nil then price = (G.GroupPrices or {})[w.group] end
        if price ~= false and tonumber(price) then
            list[#list + 1] = { name = name, price = tonumber(price), amount = w.thrown and G.ThrownStock or G.WeaponStock }
        end
    end
    local ammo = MI:GetAmmoData() or {}
    local boxes, hasBox = {}, {}
    for item, b in pairs(ammo.boxes or {}) do
        boxes[#boxes + 1] = item
        hasBox[b.ammo] = true
    end
    table.sort(boxes)
    for _, item in ipairs(boxes) do
        local price = (G.Ammo or {})[item]
        if tonumber(price) then
            list[#list + 1] = { name = item, price = tonumber(price), amount = G.AmmoStock, category = 'ammo' }
        end
    end
    -- ammo types with no box: sell the round item (thrown weapons are their own ammo and are sold above)
    local types = {}
    for t in pairs(ammo.ammo or {}) do types[#types + 1] = t end
    table.sort(types)
    for _, t in ipairs(types) do
        local a = ammo.ammo[t]
        if not hasBox[t] and a.item and not weaponOf(a.item) then
            local price = (G.RoundPrices or {})[a.item]
            if tonumber(price) then
                list[#list + 1] = { name = a.item, price = tonumber(price), amount = G.AmmoStock, category = 'ammo' }
            end
        end
    end
    for _, it in ipairs(G.Extra or {}) do list[#list + 1] = it end
    return list
end

--- Warns about stores that pay more than half of the lowest price an item is sold for (no money loops).
local function checkLoops()
    local lowest = {}
    for _, store in pairs(MS.Stores) do
        for _, e in ipairs(store.items) do
            if e.price and (not lowest[e.name] or e.price < lowest[e.name]) then lowest[e.name] = e.price end
        end
    end
    for _, store in pairs(MS.Stores) do
        for name, e in pairs(store.buys) do
            if lowest[name] and e.buyPrice > lowest[name] * 0.5 + 0.0001 then
                warn(('store %s buys %s for %s, more than half of its lowest price %s (money loop)'):format(
                    store.name, name, money(e.buyPrice), money(lowest[name])))
            end
        end
    end
end

--- Config store items whose item was not registered yet: { store, it, idx }.
local lateItems = {}

--- Adds every late item that is registered by now to its store; the rest stay waiting.
local function addLateItems()
    local left = {}
    for _, l in ipairs(lateItems) do
        local store = MS.Stores[l.store]
        if store and store.kind == 'config' then
            if MI:GetItemDef(l.it.name:lower()) then
                local e = makeEntry(l.store, l.it, l.idx)
                if e then
                    addEntry(store, e)
                    dbg(('store %s: late item %s added'):format(l.store, e.name))
                    for src, open in pairs(MS.Sessions) do
                        if open == l.store then MS.PushState(src) end
                    end
                end
            else
                left[#left + 1] = l
            end
        end
    end
    lateItems = left
end

local function buildConfigStores()
    local gunsmith
    local n = 0
    for _, s in ipairs(Config.Stores or {}) do
        local t = Config.Types[s.type]
        if t and t.enabled ~= false and s.enabled ~= false then
            local listName = s.products or t.products
            local items
            if listName == 'gunsmith' then
                gunsmith = gunsmith or MS.GunsmithItems()
                items = gunsmith
            else
                items = Config.Products[listName]
            end
            if type(items) ~= 'table' then
                warn(('store %s: product list "%s" not found, skipped'):format(tostring(s.name), tostring(listName)))
            else
                local store = build({
                    name = s.name, label = storeLabel(s), type = s.type, kind = 'config', coords = s.coords,
                    distance = s.distance, items = items, persistentStock = Config.PersistStock,
                    jobs = s.jobs, jobType = s.jobType, onDuty = s.onDuty, hours = s.hours,
                    lateList = lateItems,
                })
                store.typeLabel = _L((t.label or 'type_general') .. '_short')
                n = n + 1
            end
        elseif not t then
            warn(('store %s: unknown type "%s", skipped'):format(tostring(s.name), tostring(s.type)))
        end
    end
    return n
end

CreateThread(function()
    loadDb()
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) do
        Wait(250)
        t = t + 1
        if t == 120 then warn('waiting for MULTIinventory (ensure MULTIinventory before MULTIstores)') end
    end
    local n = buildConfigStores()
    MS.ready = true
    for _, def in ipairs(pending) do build(def) end
    pending = {}
    print(('[MULTIstores] %d stores ready'):format(n))
    TriggerEvent('MULTIstores:ready')
    -- items registered a moment later by other resources join their stores as they appear
    local waitUntil = GetGameTimer() + math.max(0, tonumber(Config.LateItemSeconds) or 60) * 1000
    while #lateItems > 0 and GetGameTimer() < waitUntil do
        Wait(500)
        addLateItems()
    end
    for _, l in ipairs(lateItems) do
        warn(('store %s: item "%s" is not in the item registry, skipped'):format(l.store, l.it.name))
    end
    lateItems = {}
    checkLoops()
end)

-- restock timer (the time of each store's last restock is kept in multistores_restock)
CreateThread(function()
    while true do
        Wait(math.max(5, tonumber(Config.Restock.CheckEverySeconds) or 60) * 1000)
        local minutes = tonumber(Config.Restock.Minutes) or 0
        if MS.ready and minutes > 0 then
            local now = os.time()
            for name, store in pairs(MS.Stores) do
                if now - (store.restockedAt or now) >= minutes * 60 then MS.Restock(name) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(MS.Sessions) do TriggerClientEvent('MULTIstores:client:close', src) end
end)

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('CreateStore', MS.CreateStore)
exports('OpenStore', MS.OpenStore)
exports('CloseStore', MS.CloseStore)
exports('DoesStoreExist', MS.DoesStoreExist)
exports('AddStock', MS.AddStock)
exports('SetPrice', MS.SetPrice)
exports('RestockStore', MS.Restock)
exports('Buy', MS.Buy)
exports('Sell', MS.Sell)
exports('IsReady', function() return MS.ready end)
exports('GetStore', function(name)
    local s = MS.Stores[name or '']
    if not s then return nil end
    local items = {}
    for _, e in ipairs(s.items) do
        items[#items + 1] = { index = e.index, name = e.name, label = e.label, price = e.price, amount = e.amount,
            buyPrice = e.buyPrice, maxStock = e.maxStock, category = e.category }
    end
    return { name = s.name, label = s.label, type = s.type, coords = s.coords, persistent = s.persistent, items = items }
end)
exports('GetStores', function()
    local out = {}
    for name, s in pairs(MS.Stores) do out[#out + 1] = { name = name, label = s.label, type = s.type, coords = s.coords } end
    return out
end)
