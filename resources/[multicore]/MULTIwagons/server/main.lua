-- ============================================================
-- MULTIwagons :: engine (server)
-- Owned wagons: buy, name, rename, sell back, take out / put away (one out
-- per character), health kept as a percentage, repair, and a MULTIinventory
-- storage per wagon ('trunk:<plate>').
--
-- Rows live in rsg-wagons' own table `rsg_wagons` (same shape, see
-- installation/rsg-wagons.sql in RSG v2's rsg-wagons, GPL v3, Phil and mack /
-- Rexshack-RedM): id, citizenid, wagon (model), custom (JSON), animals (JSON),
-- active. MULTIwagons keeps its data inside `custom`:
--   { name, plate, health (0-100), price (paid), buyMoneyType = 'cash' }
-- `custom.name` is where rsg-wagons keeps the name too. `active` = 1 while the
-- wagon is out.
--
-- The functions here are server-trusted (exports for other scripts and the
-- self-test). What a game client may ask goes through server/net.lua, which
-- checks distance, ownership and the rate limit first.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

MW = {
    ready = false,
    Out = {},       -- [wagonId] = { id, citizenid, src, plate, model, name, health, netId, pending, since }
    Viewing = {},   -- [src] = wagonId whose storage src has open
    ByModel = {},   -- [model] = Config.Wagons entry
    Points = {},    -- [name] = { def = dealer / call point, dealer = bool }
}

local MAX_BUYBACK = 0.5          -- MULTIcore rule: a buy-back never pays more than half the price
local FULL_HEALTH = 100          -- health is a percentage
local RSG_STASH = 'Wagon_Stash_' -- rsg-wagons' stash name prefix (+ row id)

for _, w in ipairs(Config.Wagons) do MW.ByModel[w.model] = w end
for _, d in ipairs(Config.Dealers or {}) do MW.Points[d.name] = { def = d, dealer = true } end
for _, c in ipairs(Config.CallPoints or {}) do
    if not MW.Points[c.name] then MW.Points[c.name] = { def = c, dealer = false } end
end

local function dbg(fmt, ...)
    if Config.Debug then print(('[MULTIwagons] ' .. fmt):format(...)) end
end

function MW.Notify(src, key, kind, ...)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info' }) end)
end

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function clampHealth(h)
    h = tonumber(h)
    if not h or h ~= h then return nil end
    return math.max(0, math.min(FULL_HEALTH, math.floor(h + 0.5)))
end
MW.Round2 = round2

function MW.Money(n) return ('%s%.2f'):format(Config.CurrencySign, n) end

function MW.GetPlayer(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end

function MW.CitizenId(src)
    local P = MW.GetPlayer(src)
    return P and P.PlayerData.citizenid or nil
end

-- one action at a time per character (awaits yield, so two calls could cross)
local locks = {}
local function locked(key, fn, ...)
    if not key then return false, 'no_player' end
    if locks[key] then return false, 'busy' end
    locks[key] = true
    local res = table.pack(pcall(fn, ...))
    locks[key] = nil
    if not res[1] then
        print(('^1[MULTIwagons] %s^7'):format(tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

-- ------------------------------------------------------------
-- rows
-- ------------------------------------------------------------

local function decode(row)
    if not row then return nil end
    local custom = row.custom
    if type(custom) == 'string' then custom = json.decode(custom) end
    if type(custom) ~= 'table' then custom = {} end
    return {
        id = tonumber(row.id),
        citizenid = row.citizenid,
        model = row.wagon,
        name = type(custom.name) == 'string' and custom.name or '',
        plate = custom.plate,
        health = clampHealth(custom.health) or FULL_HEALTH,
        price = tonumber(custom.price),
        active = tonumber(row.active) == 1,
        custom = custom,
    }
end

function MW.Get(id)
    id = tonumber(id)
    if not id then return nil end
    return decode(MySQL.single.await('SELECT * FROM rsg_wagons WHERE id = ?', { id }))
end

function MW.ListOf(citizenid)
    local out = {}
    if not citizenid then return out end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_wagons WHERE citizenid = ? ORDER BY id', { citizenid }) or {}) do
        out[#out + 1] = decode(row)
    end
    return out
end

function MW.GetByPlate(plate)
    if type(plate) ~= 'string' then return nil end
    return decode(MySQL.single.await(
        "SELECT * FROM rsg_wagons WHERE JSON_UNQUOTE(JSON_EXTRACT(custom, '$.plate')) = ? LIMIT 1", { plate }))
end

local function saveCustom(w)
    MySQL.update.await('UPDATE rsg_wagons SET custom = ? WHERE id = ?', { json.encode(w.custom), w.id })
end

local function setHealth(w, h)
    w.health = h
    w.custom.health = h
    saveCustom(w)
end

function MW.StorageId(plate) return 'trunk:' .. tostring(plate) end

local function storageSpec(w)
    local cfg = MW.ByModel[w.model] or {}
    return {
        label = w.name ~= '' and w.name or _L('wagon_' .. tostring(w.model)),
        slots = tonumber(cfg.slots) or nil,
        maxWeight = cfg.weight and (cfg.weight * 1000) or nil, -- kg -> grams
    }
end

local function ensureStorage(w)
    MI:Create(MW.StorageId(w.plate), storageSpec(w))
end

local function storageHasItems(invId)
    local inv = MI:Exists(invId)
    return inv ~= nil and type(inv.items) == 'table' and next(inv.items) ~= nil
end

local function newPlate()
    local chars = Config.PlateChars
    for _ = 1, 50 do
        local t = {}
        for i = 1, Config.PlateLength do
            local k = math.random(1, #chars)
            t[i] = chars:sub(k, k)
        end
        local plate = table.concat(t)
        if not MW.GetByPlate(plate) and not MI:Exists(MW.StorageId(plate)) then return plate end
    end
end

--- A clean wagon name, or nil when it is not allowed.
function MW.CleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[%c<>"\\`]', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local len = utf8.len(name) or #name
    if len < Config.NameMinLength or len > Config.NameMaxLength then return nil end
    return name
end

local function nameTaken(list, name, exceptId)
    local low = name:lower()
    for _, w in ipairs(list) do
        if w.id ~= exceptId and w.name:lower() == low then return true end
    end
    return false
end

--- What a dealer pays for this wagon (never more than half of the lower of paid / list price).
function MW.SellPrice(w)
    local cfg = MW.ByModel[w.model]
    local base = w.price or (cfg and cfg.price) or 0
    if cfg then base = math.min(base, cfg.price) end
    local rate = math.min(math.max(tonumber(Config.SellBackRate) or 0, 0), MAX_BUYBACK)
    return round2(base * rate)
end

--- What a dealer charges to repair this wagon (0 = nothing to repair).
function MW.RepairFee(w)
    local missing = FULL_HEALTH - (w.health or FULL_HEALTH)
    if missing <= 0 then return 0 end
    return round2(math.max(Config.Repair.DealerMinFee, missing * Config.Repair.DealerFeePerPercent))
end

--- The wagon a character has out (or nil).
function MW.OutOf(citizenid)
    if not citizenid then return nil end
    for _, o in pairs(MW.Out) do
        if o.citizenid == citizenid then return o end
    end
end

--- The wagon a netId belongs to (or nil).
function MW.OutByNetId(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    for _, o in pairs(MW.Out) do
        if o.netId == netId then return o end
    end
end

-- ------------------------------------------------------------
-- positions (server side, OneSync)
-- ------------------------------------------------------------

function MW.PlayerPos(src)
    local ped = GetPlayerPed(tonumber(src))
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- coords, entity of a wagon that is out (nil when it has no entity).
function MW.WagonEntity(o)
    if not o or not o.netId then return nil end
    local e = NetworkGetEntityFromNetworkId(o.netId)
    if not e or e == 0 or not DoesEntityExist(e) then return nil end
    return GetEntityCoords(e), e
end

local function v3(c) return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end

--- Is this position within `radius` of the named point?
function MW.NearPoint(pos, name, radius)
    local p = MW.Points[name]
    if not p or not pos then return false end
    return #(pos - v3(p.def.coords)) <= radius
end

--- Name of the dealer / call point within `radius` of pos (or nil).
function MW.PointAt(pos, radius)
    if not pos then return nil end
    for name, p in pairs(MW.Points) do
        if #(pos - v3(p.def.coords)) <= radius then return name end
        if p.def.spawn and #(pos - v3(p.def.spawn)) <= radius then return name end
    end
end

-- ------------------------------------------------------------
-- buy / rename / sell
-- ------------------------------------------------------------

--- src buys a wagon of `model` named `name`. → true, id, plate | false, err
function MW.Buy(src, model, name)
    local P = MW.GetPlayer(src)
    if not P then return false, 'no_player' end
    local cid = P.PlayerData.citizenid
    return locked(cid, function()
        local cfg = MW.ByModel[model]
        if not cfg or cfg.enabled == false then return false, 'unknown_model' end
        local clean = MW.CleanName(name)
        if not clean then return false, 'bad_name' end
        local list = MW.ListOf(cid)
        if #list >= Config.MaxWagonsPerCharacter then return false, 'limit' end
        if nameTaken(list, clean) then return false, 'name_taken' end
        local price = round2(cfg.price)
        if (tonumber(P.PlayerData.money[Config.Currency]) or 0) < price then return false, 'no_money' end
        local plate = newPlate()
        if not plate then return false, 'error' end
        if not P.Functions.RemoveMoney(Config.Currency, price, 'wagon-bought') then return false, 'no_money' end
        local custom = { name = clean, plate = plate, health = FULL_HEALTH, price = price, buyMoneyType = 'cash' }
        local id = MySQL.insert.await('INSERT INTO rsg_wagons (citizenid, wagon, custom, animals, active) VALUES (?, ?, ?, ?, 0)',
            { cid, model, json.encode(custom), '[]' })
        if not id or id <= 0 then
            P.Functions.AddMoney(Config.Currency, price, 'wagon-refund')
            return false, 'error'
        end
        ensureStorage({ id = id, model = model, name = clean, plate = plate })
        dbg('%s bought %s "%s" (%s) for %s', cid, model, clean, plate, MW.Money(price))
        TriggerEvent('MULTIwagons:bought', tonumber(src), id, model, plate)
        return true, id, plate
    end)
end

--- src renames his wagon. → true | false, err
function MW.Rename(src, id, name)
    local cid = MW.CitizenId(src)
    if not cid then return false, 'no_player' end
    return locked(cid, function()
        local w = MW.Get(id)
        if not w then return false, 'no_wagon' end
        if w.citizenid ~= cid then return false, 'not_owner' end
        local clean = MW.CleanName(name)
        if not clean then return false, 'bad_name' end
        if nameTaken(MW.ListOf(cid), clean, w.id) then return false, 'name_taken' end
        w.name, w.custom.name = clean, clean
        saveCustom(w)
        local o = MW.Out[w.id]
        if o then o.name = clean end
        if MI:Exists(MW.StorageId(w.plate)) then MI:Configure(MW.StorageId(w.plate), { label = clean }) end
        return true
    end)
end

--- src sells his wagon back to a dealer. → true, payout | false, err
function MW.Sell(src, id)
    local P = MW.GetPlayer(src)
    if not P then return false, 'no_player' end
    local cid = P.PlayerData.citizenid
    return locked(cid, function()
        local w = MW.Get(id)
        if not w then return false, 'no_wagon' end
        if w.citizenid ~= cid then return false, 'not_owner' end
        if MW.Out[w.id] then return false, 'is_out' end
        local storage = w.plate and MW.StorageId(w.plate)
        if storage and Config.SellNeedsEmptyStorage and storageHasItems(storage) then return false, 'not_empty' end
        local payout = MW.SellPrice(w)
        local gone = MySQL.update.await('DELETE FROM rsg_wagons WHERE id = ? AND citizenid = ?', { w.id, cid })
        if not gone or gone < 1 then return false, 'no_wagon' end
        if storage then
            if MI:Exists(storage) then MI:Delete(storage) end
            MySQL.update.await('DELETE FROM inventories WHERE identifier = ?', { storage })
        end
        if payout > 0 then P.Functions.AddMoney(Config.Currency, payout, 'wagon-sold') end
        dbg('%s sold %s "%s" for %s', cid, w.model, w.name, MW.Money(payout))
        TriggerEvent('MULTIwagons:sold', tonumber(src), w.id, w.model, payout)
        return true, payout
    end)
end

-- ------------------------------------------------------------
-- take out / put away
-- ------------------------------------------------------------

--- src takes his wagon out. spawn = vector4 / table {x,y,z,w} or nil (the client finds a road).
--- → true, data { id, model, plate, name, health, spawn } | false, err
function MW.TakeOut(src, id, spawn)
    local cid = MW.CitizenId(src)
    if not cid then return false, 'no_player' end
    return locked(cid, function()
        local w = MW.Get(id)
        if not w then return false, 'no_wagon' end
        if w.citizenid ~= cid then return false, 'not_owner' end
        if MW.Out[w.id] then return false, 'is_out' end
        if MW.OutOf(cid) then return false, 'already_out' end
        if w.health < Config.Health.MinToTakeOut then return false, 'broken' end
        if not w.plate then return false, 'error' end
        MW.Out[w.id] = {
            id = w.id, citizenid = cid, src = tonumber(src), plate = w.plate, model = w.model, name = w.name,
            health = w.health, netId = nil, pending = true, since = os.time(),
        }
        MySQL.update.await('UPDATE rsg_wagons SET active = 0 WHERE citizenid = ? AND id <> ?', { cid, w.id })
        MySQL.update.await('UPDATE rsg_wagons SET active = 1 WHERE id = ?', { w.id })
        ensureStorage(w)
        dbg('%s took out "%s" (%s)', cid, w.name, w.plate)
        local s = spawn and { x = spawn.x + 0.0, y = spawn.y + 0.0, z = spawn.z + 0.0, w = (spawn.w or 0.0) + 0.0 } or nil
        return true, { id = w.id, model = w.model, plate = w.plate, name = w.name, health = w.health, spawn = s }
    end)
end

--- The owner's game made the wagon: remember its entity. → true | false, err
function MW.Spawned(src, id, netId)
    local o = MW.Out[tonumber(id)]
    if not o or o.src ~= tonumber(src) or not o.pending then return false, 'no_wagon' end
    netId = tonumber(netId)
    if not netId then return false, 'error' end
    local e = NetworkGetEntityFromNetworkId(netId)
    if not e or e == 0 or not DoesEntityExist(e) then return false, 'no_entity' end
    if GetEntityModel(e) ~= joaat(o.model) then return false, 'bad_entity' end
    o.netId, o.pending = netId, false
    Entity(e).state:set('multiwagon', { id = o.id, plate = o.plate, owner = o.citizenid, model = o.model, name = o.name }, true)
    TriggerEvent('MULTIwagons:spawned', o.src, o.id, netId)
    return true
end

--- Owner's game reports the wagon's health while out (it can only go down here).
function MW.ReportHealth(src, id, pct)
    local o = MW.Out[tonumber(id)]
    local h = clampHealth(pct)
    if not o or o.src ~= tonumber(src) or not h then return false end
    if h < o.health then o.health = h end
    return true
end

--- Puts a wagon that is out away: entity removed, health saved, active = 0. Server-trusted.
--- health = last health from the owner's game (only lowers the saved value), reason for the log.
function MW.PutAway(id, health, reason)
    id = tonumber(id)
    local o = MW.Out[id]
    if not o then return false, 'not_out' end
    MW.Out[id] = nil
    local h = clampHealth(health)
    if h and h < o.health then o.health = h end
    local _, e = MW.WagonEntity(o)
    if e then DeleteEntity(e) end
    if o.src then TriggerClientEvent('MULTIwagons:client:gone', o.src, o.id, o.netId) end
    for viewer, wid in pairs(MW.Viewing) do
        if wid == id then
            MW.Viewing[viewer] = nil
            MI:Close(viewer)
        end
    end
    local w = MW.Get(id)
    if w then
        w.custom.health = o.health
        MySQL.update.await('UPDATE rsg_wagons SET custom = ?, active = 0 WHERE id = ?', { json.encode(w.custom), id })
    end
    dbg('"%s" (%s) put away (%s), health %d', o.name, o.plate, tostring(reason or 'store'), o.health)
    TriggerEvent('MULTIwagons:stored', o.src, id, reason or 'store')
    return true
end

--- src puts his own wagon away. → true | false, err
function MW.Store(src, id, health)
    local cid = MW.CitizenId(src)
    if not cid then return false, 'no_player' end
    local o = id and MW.Out[tonumber(id)] or MW.OutOf(cid)
    if not o then return false, 'not_out' end
    if o.citizenid ~= cid then return false, 'not_owner' end
    return MW.PutAway(o.id, health, 'store')
end

-- ------------------------------------------------------------
-- repair
-- ------------------------------------------------------------

local function repaired(w)
    setHealth(w, FULL_HEALTH)
    local o = MW.Out[w.id]
    if o then
        o.health = FULL_HEALTH
        if o.src then TriggerClientEvent('MULTIwagons:client:repaired', o.src, o.id, o.netId) end
    end
end

--- Repairs src's wagon. how = 'dealer' (pays the fee) | 'item' (uses one repair kit; the wagon must be out).
--- → true, fee | false, err
function MW.Repair(src, id, how)
    local P = MW.GetPlayer(src)
    if not P then return false, 'no_player' end
    local cid = P.PlayerData.citizenid
    return locked(cid, function()
        local w
        if how == 'item' then
            local o = id and MW.Out[tonumber(id)] or MW.OutOf(cid)
            if not o then return false, 'not_out' end
            w = MW.Get(o.id)
            if w then w.health = math.min(w.health, o.health) end
        else
            w = MW.Get(id)
            local o = w and MW.Out[w.id]
            if o then w.health = math.min(w.health, o.health) end
        end
        if not w then return false, 'no_wagon' end
        if w.citizenid ~= cid then return false, 'not_owner' end
        if w.health >= FULL_HEALTH then return false, 'not_damaged' end
        if how == 'item' then
            local item = Config.Repair.Item
            if not item or item == '' then return false, 'error' end
            local ok = MI:RemoveItem(MI:PlayerInv(src), item, 1, nil, nil, 'wagon-repair')
            if not ok then return false, 'no_item' end
            repaired(w)
            return true, 0
        end
        local fee = MW.RepairFee(w)
        if (tonumber(P.PlayerData.money[Config.Currency]) or 0) < fee then return false, 'no_money' end
        if not P.Functions.RemoveMoney(Config.Currency, fee, 'wagon-repair') then return false, 'no_money' end
        repaired(w)
        return true, fee
    end)
end

-- ------------------------------------------------------------
-- storage
-- ------------------------------------------------------------

--- Opens the storage of wagon `id` for src. Server-trusted (net.lua checks distance and access).
function MW.OpenStorage(src, id)
    local w = MW.Get(id)
    if not w or not w.plate then return false, 'no_wagon' end
    local ok, err = MI:Open(tonumber(src), MW.StorageId(w.plate), storageSpec(w))
    if ok then MW.Viewing[tonumber(src)] = w.id end
    return ok and true or false, err
end

AddEventHandler('MULTIinventory:closed', function(src)
    MW.Viewing[tonumber(src)] = nil
end)

-- ------------------------------------------------------------
-- rsg-wagons stashes -> MULTIwagons storage (once)
-- ------------------------------------------------------------

local function migrateStash(w)
    local old = 'stash:' .. RSG_STASH .. w.id
    local inv = MI:Exists(old)
    if not inv or type(inv.items) ~= 'table' then return 0 end
    local target, moved = MW.StorageId(w.plate), 0
    for _, s in pairs(inv.items) do
        local ok = MI:AddItem(target, s.name, s.amount, s.info, nil, 'rsg-wagons-migrate')
        if ok then moved = moved + 1 else print(('^3[MULTIwagons] could not move %s x%s from %s^7'):format(s.name, s.amount, old)) end
    end
    MI:Save(target, true)
    MI:Delete(old)
    return moved
end

--- Rows written by rsg-wagons have no plate / health: give them one, and their old stash.
local function upgradeRows()
    local fixed = 0
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_wagons') or {}) do
        local w = decode(row)
        if not w.plate then
            w.plate = newPlate()
            if w.plate then
                w.custom.plate = w.plate
                w.custom.health = w.custom.health or FULL_HEALTH
                if w.name == '' then w.custom.name = _L('wagon_' .. tostring(w.model)); w.name = w.custom.name end
                saveCustom(w)
                ensureStorage(w)
                if Config.MigrateRsgStashes then migrateStash(w) end
                fixed = fixed + 1
            end
        end
    end
    if fixed > 0 then print(('[MULTIwagons] %d wagons from rsg-wagons given a plate and storage'):format(fixed)) end
end

-- ------------------------------------------------------------
-- repair kit
-- ------------------------------------------------------------

local function registerItems()
    for name, def in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) then MI:RegisterItem(def) end
    end
    local item = Config.Repair.Item
    if item and item ~= '' then
        if MI:GetItemDef(item) then
            MI:RegisterUsable(item, function(src)
                -- the game shows the work, then asks 'MULTIwagons:repairKit' (net.lua)
                TriggerClientEvent('MULTIwagons:client:useRepairKit', src)
            end)
        else
            print(('^3[MULTIwagons] repair item "%s" is not in the item registry; the kit is off^7'):format(item))
        end
    end
end

-- ------------------------------------------------------------
-- start, watch, leave
-- ------------------------------------------------------------

local SCHEMA = [[CREATE TABLE IF NOT EXISTS `rsg_wagons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL DEFAULT '0',
  `wagon` varchar(50) NOT NULL DEFAULT '0',
  `custom` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`custom`)),
  `animals` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`animals`)),
  `active` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

CreateThread(function()
    math.randomseed(os.time())
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    MySQL.query.await(SCHEMA)
    -- nothing is out after a (re)start
    MySQL.update.await('UPDATE rsg_wagons SET active = 0 WHERE active <> 0')
    registerItems()
    upgradeRows()
    for model in pairs(MW.ByModel) do
        if not Locales.en['wagon_' .. model] then print(('^3[MULTIwagons] no label for wagon "%s" (locale key wagon_%s)^7'):format(model, model)) end
    end
    if (tonumber(Config.SellBackRate) or 0) > MAX_BUYBACK then
        print(('^3[MULTIwagons] Config.SellBackRate %.2f is above %.1f; %.1f is used^7'):format(Config.SellBackRate, MAX_BUYBACK, MAX_BUYBACK))
    end
    MW.ready = true
    TriggerEvent('MULTIwagons:ready')
    print('^2[MULTIwagons] ready^7')
end)

-- wagons whose entity is gone are put away; take-outs never confirmed are undone;
-- storage left open by a player who walked away is closed
CreateThread(function()
    while true do
        Wait(math.max(1, Config.WatchSeconds) * 1000)
        local now = os.time()
        for id, o in pairs(MW.Out) do
            if o.pending then
                if now - o.since > Config.SpawnTimeoutSeconds then MW.PutAway(id, nil, 'spawn_timeout') end
            elseif not MW.WagonEntity(o) then
                MW.PutAway(id, nil, 'gone')
            end
        end
        if Config.ServerDistanceCheck then
            for src, id in pairs(MW.Viewing) do
                local o = MW.Out[id]
                local wpos = MW.WagonEntity(o)
                local ppos = MW.PlayerPos(src)
                if wpos and ppos and #(ppos - wpos) > Config.StorageServerDistance then
                    MW.Viewing[src] = nil
                    MI:Close(src)
                end
            end
        end
    end
end)

local function onLeave(src)
    src = tonumber(src)
    if not src then return end
    MW.Viewing[src] = nil
    for id, o in pairs(MW.Out) do
        if o.src == src then
            if Config.DespawnOnLeave then MW.PutAway(id, nil, 'left') else o.src = nil end
        end
    end
end
AddEventHandler('RSGCore:Server:OnPlayerUnload', onLeave)
AddEventHandler('playerDropped', function() onLeave(source) end)

-- a deleted character's wagons and their storage go with it
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    for _, w in ipairs(MW.ListOf(citizenid)) do
        if MW.Out[w.id] then MW.PutAway(w.id, nil, 'deleted') end
        if w.plate then
            local storage = MW.StorageId(w.plate)
            if MI:Exists(storage) then MI:Delete(storage) end
        end
    end
    MySQL.update.await('DELETE FROM rsg_wagons WHERE citizenid = ?', { citizenid })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, o in pairs(MW.Out) do
        local _, e = MW.WagonEntity(o)
        if e then DeleteEntity(e) end
    end
end)

-- ------------------------------------------------------------
-- exports (server-trusted: callers check their own rules)
-- ------------------------------------------------------------

local function pub(w)
    if not w then return nil end
    local o = MW.Out[w.id]
    return {
        id = w.id, citizenid = w.citizenid, model = w.model, name = w.name, plate = w.plate,
        health = o and o.health or w.health, out = o ~= nil, netId = o and o.netId or nil,
        storage = w.plate and MW.StorageId(w.plate) or nil,
    }
end
MW.Public = pub

exports('IsReady', function() return MW.ready end)
exports('GetWagons', function(srcOrCitizenId)
    local cid = type(srcOrCitizenId) == 'string' and srcOrCitizenId or MW.CitizenId(srcOrCitizenId)
    local out = {}
    for _, w in ipairs(MW.ListOf(cid)) do out[#out + 1] = pub(w) end
    return out
end)
exports('GetWagon', function(id) return pub(MW.Get(id)) end)
exports('GetWagonByPlate', function(plate) return pub(MW.GetByPlate(plate)) end)
exports('GetActiveWagon', function(srcOrCitizenId)
    local cid = type(srcOrCitizenId) == 'string' and srcOrCitizenId or MW.CitizenId(srcOrCitizenId)
    local o = MW.OutOf(cid)
    return o and pub(MW.Get(o.id)) or nil
end)
exports('GetWagonByNetId', function(netId)
    local o = MW.OutByNetId(netId)
    return o and pub(MW.Get(o.id)) or nil
end)
exports('GetStorageId', function(idOrPlate)
    local w = tonumber(idOrPlate) and MW.Get(idOrPlate) or MW.GetByPlate(idOrPlate)
    return w and w.plate and MW.StorageId(w.plate) or nil
end)
exports('GetModelConfig', function(model) return MW.ByModel[model] end)
exports('Buy', MW.Buy)
exports('Sell', MW.Sell)
exports('Rename', MW.Rename)
exports('TakeOut', MW.TakeOut)
exports('Store', MW.Store)
exports('PutAway', MW.PutAway)
exports('Repair', MW.Repair)
exports('OpenStorage', MW.OpenStorage)
exports('SellPrice', function(id) local w = MW.Get(id) return w and MW.SellPrice(w) or nil end)
exports('RepairFee', function(id) local w = MW.Get(id) return w and MW.RepairFee(w) or nil end)
