-- ============================================================
-- MULTIwagons :: server
-- Owned wagons: buy, name, change (paint, stripes, extras, cargo, lanterns),
-- select and call, sell, carcass / pelt storage, a MULTIinventory storage per
-- wagon ('trunk:<id>') and owner permission for other players.
-- Based on Phil's wagon script (server.lua), fitted to MULTIcore.
--
-- Rows live in the table `rsg_wagons` (kept under that name so wagons from
-- earlier versions carry over): id, citizenid, wagon (model), custom (JSON),
-- animals (JSON), active. `custom` = { name, tint, livery, props, lantern,
-- extras, buyMoneyType, plate }. `active` = 1 on the wagon the player has
-- selected; it is the one /wagon calls.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local Core = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

MW = {
    ready = false,
    Wagons = {},    -- [netId] = { owner = src, citizenid, wagonID, wagonModel, plate, authorized = {} }
    Viewing = {},   -- [src] = netId whose storage src has open
    Asks = {},      -- [netId] = { [requesterSrc] = os.time() } storage requests waiting for the owner
}
local wagons = MW.Wagons
local wagonAnimalsData = {}
local OLD_STASH = 'Wagon_Stash_'   -- old stash name prefix (+ row id)

local function dbg(fmt, ...)
    if Config.Debug then print(('[MULTIwagons] ' .. fmt):format(...)) end
end

--- A message to one player in MULTIcore's notifications.
function MW.Notify(src, key, kind, ...)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info' }) end)
end
local notify = MW.Notify

-- ------------------------------------------------------------
-- players and money
-- ------------------------------------------------------------

local function resolveCashType(moneyType)
    if moneyType == 'gold' then return Config.MoneyType.gold or 'gold' end
    return Config.MoneyType.money or 'cash'
end

local function getPlayer(src) return Core.Functions.GetPlayer(tonumber(src)) end

function MW.CitizenId(src)
    local Player = getPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end
local getCitizenId = MW.CitizenId

local function getName(src)
    local Player = getPlayer(src)
    if not Player then return nil, nil end
    local ci = Player.PlayerData.charinfo or {}
    return ci.firstname, ci.lastname
end

local function removeMoney(src, amount, moneyType)
    local Player = getPlayer(src)
    if not Player then return false end
    local cashType = resolveCashType(moneyType)
    if (Player.PlayerData.money[cashType] or 0) < amount then return false end
    return Player.Functions.RemoveMoney(cashType, amount) and true or false
end

local function addMoney(src, amount, moneyType)
    local Player = getPlayer(src)
    if not Player then return false end
    return Player.Functions.AddMoney(resolveCashType(moneyType), amount) and true or false
end

function MW.PlayerPos(src)
    local ped = GetPlayerPed(tonumber(src))
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- The entity of a registered wagon and its position (nil when gone).
function MW.Entity(netId)
    local e = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not e or e == 0 or not DoesEntityExist(e) then return nil end
    return e, GetEntityCoords(e)
end

local function nearDealer(src)
    if not Config.ServerDistanceCheck then return true end
    local pos = MW.PlayerPos(src)
    if not pos then return false end
    for _, s in pairs(Config.Stores) do
        if #(pos - vector3(s.coords.x, s.coords.y, s.coords.z)) <= Config.DealerUseDistance then return true end
    end
    return false
end

MW.NearDealer = nearDealer

local function nearWagon(src, netId, dist)
    if not Config.ServerDistanceCheck then return true end
    local _, wpos = MW.Entity(netId)
    local ppos = MW.PlayerPos(src)
    return wpos ~= nil and ppos ~= nil and #(ppos - wpos) <= dist
end

-- ------------------------------------------------------------
-- wagon models and rows
-- ------------------------------------------------------------

--- The Config.Wagons entry of a model, and its category.
function MW.ModelCfg(model)
    for cat, set in pairs(Config.Wagons) do
        if set[model] then return set[model], cat end
    end
end

local function decode(row)
    local custom = json.decode(row.custom or '{}')
    if type(custom) ~= 'table' then custom = {} end
    return { id = row.id, citizenid = row.citizenid, model = row.wagon, custom = custom, active = tonumber(row.active) == 1 }
end

function MW.Get(id)
    id = tonumber(id)
    if not id then return nil end
    local row = MySQL.single.await('SELECT * FROM rsg_wagons WHERE id = ?', { id })
    return row and decode(row) or nil
end

function MW.ListOf(citizenid)
    if not citizenid then return {} end
    local out = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_wagons WHERE citizenid = ? ORDER BY id', { citizenid }) or {}) do
        out[#out + 1] = decode(row)
    end
    return out
end

--- One of src's wagons (nil when it is not theirs).
local function ownWagon(src, id)
    local w = MW.Get(id)
    if not w or w.citizenid ~= getCitizenId(src) then return nil end
    return w
end

local function byName(citizenid, name)
    if type(name) ~= 'string' then return nil end
    for _, w in ipairs(MW.ListOf(citizenid)) do
        if w.custom.name == name then return w end
    end
end
MW.ByName = byName

local function saveCustom(w)
    MySQL.update.await('UPDATE rsg_wagons SET custom = ? WHERE id = ?', { json.encode(w.custom), w.id })
end

--- The registered (spawned) entry of wagon id, and its netId.
function MW.OutById(id)
    id = tonumber(id)
    for netId, r in pairs(wagons) do
        if r.wagonID == id then return r, netId end
    end
end

-- ------------------------------------------------------------
-- storage (MULTIinventory 'trunk:<plate>')
-- ------------------------------------------------------------

function MW.StorageId(plate) return 'trunk:' .. tostring(plate) end

local function storageSpec(w)
    local cfg = MW.ModelCfg(w.model) or {}
    return {
        label = (w.custom.name and w.custom.name ~= '') and w.custom.name or _L('storage'),
        slots = tonumber(cfg.slots) or nil,
        maxWeight = cfg.maxWeight and (cfg.maxWeight * 1000) or nil, -- kg -> grams
    }
end

local function plateTaken(plate)
    local n = MySQL.scalar.await("SELECT COUNT(*) FROM rsg_wagons WHERE custom LIKE ?", { '%"plate":"' .. plate .. '"%' }) or 0
    return n > 0 or MI:Exists(MW.StorageId(plate)) ~= nil
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
        if not plateTaken(plate) then return plate end
    end
end

local function ensureStorage(w)
    if not w.custom.plate then
        w.custom.plate = newPlate()
        if not w.custom.plate then return false end
        saveCustom(w)
    end
    MI:Create(MW.StorageId(w.custom.plate), storageSpec(w))
    return true
end

local function storageHasItems(w)
    if not w.custom.plate then return false end
    local inv = MI:Exists(MW.StorageId(w.custom.plate))
    return inv ~= nil and type(inv.items) == 'table' and next(inv.items) ~= nil
end

local function deleteStorage(w)
    if not w.custom.plate then return end
    local id = MW.StorageId(w.custom.plate)
    if MI:Exists(id) then MI:Delete(id) end
end

--- Opens the storage of wagon `id` for src. Server-trusted (callers check distance and access).
function MW.OpenStorage(src, id)
    local w = MW.Get(id)
    if not w then return false, 'no_wagon' end
    if not ensureStorage(w) then return false, 'error' end
    local ok, err = MI:Open(tonumber(src), MW.StorageId(w.custom.plate), storageSpec(w))
    return ok and true or false, err
end

AddEventHandler('MULTIinventory:closed', function(src)
    MW.Viewing[tonumber(src)] = nil
end)

-- ------------------------------------------------------------
-- buy, list, select, change, sell
-- ------------------------------------------------------------

local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[%c<>"\\`]', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local len = utf8.len(name) or #name
    if len < 1 or len > Config.NameMaxLength then return nil end
    return name
end

--- Buys `model` for src under `name`. moneyType 'cash' (default) or 'gold'.
function MW.Buy(src, model, name, moneyType)
    local citizenid = getCitizenId(src)
    if not citizenid then return false end
    local cfg = type(model) == 'string' and MW.ModelCfg(model)
    if not cfg then return false end
    name = cleanName(name)
    if not name then
        notify(src, 'bad_name', 'error', Config.NameMaxLength)
        return false
    end
    moneyType = moneyType == 'gold' and 'gold' or 'cash'
    local price = (moneyType == 'gold') and cfg.priceGold or cfg.price
    if not price then
        notify(src, 'no_price', 'error')
        return false
    end

    local list = MW.ListOf(citizenid)
    if #list >= Config.maxWagonsPerPlayer then
        notify(src, 'max_wagons', 'error')
        return false
    end
    for _, w in ipairs(list) do
        if w.custom.name == name then
            notify(src, 'name_exists', 'error')
            return false
        end
    end

    if not removeMoney(src, price, moneyType) then
        notify(src, 'no_money', 'error')
        return false
    end

    local custom = { name = name, tint = 0, livery = -1, props = false, extras = {}, buyMoneyType = moneyType, plate = newPlate() }
    local id = MySQL.insert.await('INSERT INTO rsg_wagons (citizenid, wagon, custom, animals) VALUES (?, ?, ?, ?)',
        { citizenid, model, json.encode(custom), json.encode({}) })
    if not id or id <= 0 then
        addMoney(src, price, moneyType)
        notify(src, 'error', 'error')
        return false
    end
    ensureStorage({ id = id, model = model, custom = custom })
    notify(src, 'bought', 'success')
    TriggerEvent('MULTIwagons:bought', src, id, model)
    return true, id
end

--- The dealer page list: { id, model, label, custom, active }.
function MW.MyWagons(src)
    local out = {}
    for _, w in ipairs(MW.ListOf(getCitizenId(src))) do
        local cfg = MW.ModelCfg(w.model)
        out[#out + 1] = { id = w.id, model = w.model, label = cfg and cfg.name or w.model, custom = w.custom, active = w.active }
    end
    return out
end

--- Sends src's selected wagon to its game, which then makes it.
--- No wagon selected yet (e.g. wagons from an earlier version): the first one is selected.
function MW.CallWagon(src)
    src = tonumber(src)
    local citizenid = getCitizenId(src)
    if not citizenid then return end
    local row = MySQL.single.await('SELECT * FROM rsg_wagons WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if not row then
        row = MySQL.single.await('SELECT * FROM rsg_wagons WHERE citizenid = ? ORDER BY id LIMIT 1', { citizenid })
        if row then MySQL.update.await('UPDATE rsg_wagons SET active = 1 WHERE id = ?', { row.id }) end
    end
    if not row then
        notify(src, 'no_wagon', 'error')
        return
    end
    local w = decode(row)
    ensureStorage(w)
    TriggerClientEvent('MULTIwagons:client:receiveWagonData', src, w.model, w.custom, json.decode(row.animals or '[]') or {}, w.id)
end

--- Selects wagon id as src's wagon and calls it.
function MW.Activate(src, id)
    local w = ownWagon(src, id)
    if not w then
        notify(src, 'no_wagon_found', 'error')
        return false
    end
    if not nearDealer(src) then
        notify(src, 'too_far_dealer', 'error')
        return false
    end
    MySQL.update.await('UPDATE rsg_wagons SET active = 0 WHERE citizenid = ? AND active = 1', { w.citizenid })
    MySQL.update.await('UPDATE rsg_wagons SET active = 1 WHERE id = ?', { w.id })
    Wait(500)
    MW.CallWagon(src)
    return true
end

local function sanitiseValue(customType, value)
    if customType == 'extra' then
        if type(value) ~= 'table' then return nil end
        local out = {}
        for _, v in ipairs(value) do
            local n = tonumber(v)
            if n and n >= 0 and n <= 20 then out[#out + 1] = math.floor(n) end
        end
        return out
    elseif customType == 'livery' or customType == 'tint' then
        local n = tonumber(value)
        if not n then return nil end
        return math.floor(n)
    elseif customType == 'props' or customType == 'lantern' then
        if value == false or value == -1 or value == '-1' then return false end
        if type(value) ~= 'string' or #value > 64 or not value:match('^[%w_]+$') then return nil end
        return value
    end
end

--- Pays for and saves one change on wagon id.
function MW.SaveCustomization(src, id, customType, value)
    local price = Config.CustomPrice and Config.CustomPrice[customType] or 0
    local w = ownWagon(src, id)
    if not w or price <= 0 then
        notify(src, 'custom_failed', 'error')
        return false
    end
    if not nearDealer(src) then
        notify(src, 'too_far_dealer', 'error')
        return false
    end
    local clean = sanitiseValue(customType, value)
    if clean == nil then
        notify(src, 'custom_failed', 'error')
        return false
    end
    if not removeMoney(src, price) then
        notify(src, 'no_money', 'error')
        return false
    end
    if customType == 'extra' then
        w.custom.extras = clean
        w.custom.extra = nil
    else
        w.custom[customType] = clean
    end
    saveCustom(w)
    notify(src, 'custom_saved', 'success')
    return true
end

--- Removes a registered wagon from the world.
local function despawn(netId)
    local r = wagons[netId]
    local e = MW.Entity(netId)
    if e then DeleteEntity(e) end
    wagons[netId] = nil
    MW.Asks[netId] = nil
    for viewer, n in pairs(MW.Viewing) do
        if n == netId then
            MW.Viewing[viewer] = nil
            pcall(function() MI:Close(viewer) end)
        end
    end
    if r then
        if r.owner then TriggerClientEvent('MULTIwagons:client:forgetWagon', r.owner, netId) end
        TriggerEvent('MULTIwagons:stored', r.owner, r.wagonID)
    end
end
MW.Despawn = despawn

--- Sells wagon id back for its price times Config.Sell.
function MW.Sell(src, id)
    local w = ownWagon(src, id)
    if not w then
        notify(src, 'no_wagon_found', 'error')
        return false
    end
    if not nearDealer(src) then
        notify(src, 'too_far_dealer', 'error')
        return false
    end
    if Config.SellNeedsEmptyStorage and storageHasItems(w) then
        notify(src, 'not_empty', 'error')
        return false
    end

    local buyMoneyType = w.custom.buyMoneyType == 'gold' and 'gold' or 'cash'
    local cfg = MW.ModelCfg(w.model)
    local price = cfg and ((buyMoneyType == 'gold') and cfg.priceGold or cfg.price)
    if not price and cfg then
        -- bought with the other money, or that price was removed from the config
        buyMoneyType = (buyMoneyType == 'gold') and 'cash' or 'gold'
        price = (buyMoneyType == 'gold') and cfg.priceGold or cfg.price
    end
    if not price then
        notify(src, 'no_price', 'error')
        return false
    end

    local _, netId = MW.OutById(w.id)
    if netId then despawn(netId) end
    local payout = math.floor(price * (Config.Sell or 0.1) * 100 + 0.5) / 100
    MySQL.update.await('DELETE FROM rsg_wagons WHERE id = ?', { w.id })
    wagonAnimalsData[w.id] = nil
    deleteStorage(w)
    addMoney(src, payout, buyMoneyType)
    local amount = (buyMoneyType == 'gold') and (tostring(payout) .. ' ' .. _L('gold')) or (Config.CurrencySign .. tostring(payout))
    notify(src, 'sold', 'success', amount)
    TriggerEvent('MULTIwagons:sold', src, w.id, w.model, payout)
    return true, payout
end

-- ------------------------------------------------------------
-- wagons in the world
-- ------------------------------------------------------------

--- The owner's game made wagon id: remember it, mark the entity for everyone.
function MW.Register(src, netId, wagonID, model)
    netId = tonumber(netId)
    local w = ownWagon(src, wagonID)
    if not netId or not w or w.model ~= model then return end
    -- one wagon out per character: an older one of the same owner goes
    for n, r in pairs(wagons) do
        if n ~= netId and (r.citizenid == w.citizenid or r.wagonID == w.id) then despawn(n) end
    end
    ensureStorage(w)
    wagons[netId] = {
        owner = src, citizenid = w.citizenid, wagonID = w.id, wagonModel = w.model, plate = w.custom.plate,
        authorized = wagons[netId] and wagons[netId].authorized or {},
    }
    CreateThread(function()
        local e
        for _ = 1, 40 do
            e = MW.Entity(netId)
            if e then break end
            Wait(50)
        end
        if e and wagons[netId] then
            Entity(e).state:set('multiwagon', {
                id = w.id, owner = w.citizenid, model = w.model, name = w.custom.name, plate = w.custom.plate,
            }, true)
        end
    end)
    dbg('wagon %s (%s) out for %s as net %s', w.id, w.model, src, netId)
    TriggerEvent('MULTIwagons:spawned', src, w.id, netId)
end

--- Owner, wagon id and model of a wagon that is out (the old script's isWagonRegistered shape).
function MW.IsRegistered(src, netId)
    local r = wagons[tonumber(netId)]
    if not r then return false end
    return true, src == r.owner, r.wagonID, r.wagonModel, tonumber(netId)
end

--- The owner sends their wagon away (or anyone, for a wagon nobody owns any more).
function MW.Remove(src, netId)
    netId = tonumber(netId)
    local r = netId and wagons[netId]
    if not r then return end
    if r.owner ~= src and r.citizenid ~= getCitizenId(src) then
        notify(src, 'no_permission', 'error')
        return
    end
    despawn(netId)
end

--- src wants the storage of the wagon netId: open it, or ask its owner.
function MW.OpenStash(src, netId)
    netId = tonumber(netId)
    local r = netId and wagons[netId]
    if not r then
        notify(src, 'no_wagon_found', 'error')
        return
    end
    local citizenId = getCitizenId(src)
    if not citizenId then return end
    if not nearWagon(src, netId, Config.StorageServerDistance) then
        notify(src, 'too_far', 'error')
        return
    end
    local isAuthorized = src == r.owner or citizenId == r.citizenid or Config.StorageOpenTo == 'anyone'
        or (r.authorized and r.authorized[citizenId])
    if isAuthorized then
        local ok, err = MW.OpenStorage(src, r.wagonID)
        if ok then MW.Viewing[src] = netId end
        dbg('storage of wagon %s for %s: %s %s', r.wagonID, src, tostring(ok), tostring(err))
        return
    end
    -- ask the owner (once a minute per player)
    MW.Asks[netId] = MW.Asks[netId] or {}
    local last = MW.Asks[netId][src]
    if last and os.time() - last < 60 then
        notify(src, 'asked', 'info')
        return
    end
    MW.Asks[netId][src] = os.time()
    local firstname, lastname = getName(src)
    TriggerClientEvent('MULTIwagons:client:askOwnerPermission', r.owner, {
        netId = netId, requester = src,
        name = ((firstname or '') .. ' ' .. (lastname or '')):match('^%s*(.-)%s*$'),
    })
    notify(src, 'asked', 'info')
end

--- The owner answered a storage request.
function MW.AnswerPermission(src, netId, requester, allow)
    netId, requester = tonumber(netId), tonumber(requester)
    local r = netId and wagons[netId]
    if not r or r.owner ~= src then return end
    local asks = MW.Asks[netId]
    if not asks or not asks[requester] then return end
    asks[requester] = nil
    if not allow then
        notify(requester, 'no_permission', 'error')
        return
    end
    local cid = getCitizenId(requester)
    if not cid then return end
    r.authorized = r.authorized or {}
    r.authorized[cid] = true
    notify(requester, 'have_permission', 'success')
end

--- The owner gives or takes back storage access by citizenid ('add' / 'remove').
function MW.UpdateAuth(src, netId, citizenID, action)
    local r = wagons[tonumber(netId)]
    if not r or not citizenID or r.owner ~= src then return end
    r.authorized = r.authorized or {}
    if action == 'add' then
        r.authorized[citizenID] = true
    elseif action == 'remove' then
        r.authorized[citizenID] = nil
    end
end

-- ------------------------------------------------------------
-- carcasses and pelts
-- ------------------------------------------------------------

local function GetLabelFromModel(item)
    if item.type == 'animal' then
        local entry = Config.AnimalsStorage[item.model]
        return entry and entry.label
    elseif item.type == 'pelt' then
        local entry = Config.AnimalsStorage[item.peltquality]
        return entry and entry.label
    end
end

local function loadAnimals(wagonId)
    if wagonAnimalsData[wagonId] then return wagonAnimalsData[wagonId] end
    local raw = MySQL.scalar.await('SELECT animals FROM rsg_wagons WHERE id = ? LIMIT 1', { wagonId })
    local decoded = raw and json.decode(raw) or {}
    wagonAnimalsData[wagonId] = type(decoded) == 'table' and decoded or {}
    return wagonAnimalsData[wagonId]
end

function MW.AnimalMenu(wagonId)
    wagonId = tonumber(wagonId)
    if not wagonId then return {} end
    local menuData = {}
    for _, item in ipairs(loadAnimals(wagonId)) do
        menuData[#menuData + 1] = { label = GetLabelFromModel(item) or _L('unknown_item'), infos = item }
    end
    return menuData
end

local function sameAnimal(a, b)
    return a.model == b.model and a.type == b.type and (
        (b.type == 'animal' and a.outfit == b.outfit and a.skinned == b.skinned and a.quality == b.quality) or
        (b.type == 'pelt' and a.peltquality == b.peltquality)
    )
end

local function countAnimals(list)
    local n = 0
    for _, a in ipairs(list) do n = n + (tonumber(a.quantity) or 1) end
    return n
end

--- Adds (remove = false) or takes one (remove = true). Returns true when it changed something.
local function updateAndSave(wagonId, animal, remove)
    local animals = loadAnimals(wagonId)
    local foundIndex
    for i, a in ipairs(animals) do
        if sameAnimal(a, animal) then foundIndex = i break end
    end
    if remove then
        if not foundIndex then return false end
        local qty = animals[foundIndex].quantity or 1
        if qty > 1 then animals[foundIndex].quantity = qty - 1 else table.remove(animals, foundIndex) end
    else
        if foundIndex then
            animals[foundIndex].quantity = (animals[foundIndex].quantity or 1) + 1
        else
            animal.quantity = 1
            animals[#animals + 1] = animal
        end
    end
    MySQL.update.await('UPDATE rsg_wagons SET animals = ? WHERE id = ?', { json.encode(animals), wagonId })
    return true
end

--- src puts the carcass / pelt they carry into the wagon netId.
function MW.StoreAnimal(src, netId, animal)
    local r = wagons[tonumber(netId)]
    if not r or type(animal) ~= 'table' then return false end
    if not nearWagon(src, netId, Config.StorageServerDistance) then
        notify(src, 'too_far', 'error')
        return false
    end
    local cfg = MW.ModelCfg(r.wagonModel)
    local max = cfg and tonumber(cfg.maxAnimals) or 0
    if max <= 0 then
        notify(src, 'no_animal_storage', 'error')
        return false
    end
    if animal.type ~= 'animal' and animal.type ~= 'pelt' then return false end
    if animal.type == 'animal' and not Config.AnimalsStorage[animal.model] then return false end
    if countAnimals(loadAnimals(r.wagonID)) >= max then
        notify(src, 'wagon_full', 'error')
        return false
    end
    local clean = {
        type = animal.type, model = tonumber(animal.model), peltquality = tonumber(animal.peltquality),
        outfit = tonumber(animal.outfit), skinned = animal.skinned == true or animal.skinned == 1,
        damage = tonumber(animal.damage) or 0, quality = tonumber(animal.quality) or 0,
        metatag = type(animal.metatag) == 'table' and animal.metatag or nil,
    }
    return updateAndSave(r.wagonID, clean, false)
end

--- The owner takes one carcass / pelt out of their wagon.
function MW.TakeAnimal(src, wagonId, infos)
    wagonId = tonumber(wagonId)
    if not wagonId or type(infos) ~= 'table' then return end
    local r, netId = MW.OutById(wagonId)
    if not r or (r.owner ~= src and r.citizenid ~= getCitizenId(src)) then
        notify(src, 'no_permission', 'error')
        return
    end
    if not nearWagon(src, netId, Config.StorageServerDistance) then
        notify(src, 'too_far', 'error')
        return
    end
    -- find the stored entry first, so only what is really in the wagon comes out
    local stored
    for _, a in ipairs(loadAnimals(wagonId)) do
        if sameAnimal(a, infos) then stored = a break end
    end
    if not stored then return end
    local copy = {}
    for k, v in pairs(stored) do copy[k] = v end
    if updateAndSave(wagonId, copy, true) then
        TriggerClientEvent('MULTIwagons:client:spawnAnimal', src, copy)
    end
end

-- ------------------------------------------------------------
-- chop shop hooks (server/chop.lua)
-- ------------------------------------------------------------

function MW.GetRegistered(netId) return wagons[tonumber(netId)] end

--- Scrapping destroys an owned wagon for good, row and storage included.
function MW.ScrapWagon(wagonID)
    local w = MW.Get(wagonID)
    if not w then return end
    wagonAnimalsData[w.id] = nil
    MySQL.update.await('DELETE FROM rsg_wagons WHERE id = ?', { w.id })
    deleteStorage(w)
    for netId, r in pairs(wagons) do
        if r.wagonID == w.id then despawn(netId) end
    end
end

function MW.StorageHasItems(wagonID)
    local w = MW.Get(wagonID)
    return w ~= nil and storageHasItems(w)
end

-- ------------------------------------------------------------
-- network events and callbacks (server/compat.lua adds the old names)
-- ------------------------------------------------------------

RegisterNetEvent('MULTIwagons:server:buyWagon', function(model, name, moneyType)
    local src = source
    if not nearDealer(src) then return notify(src, 'too_far_dealer', 'error') end
    MW.Buy(src, model, name, moneyType)
end)
RegisterNetEvent('MULTIwagons:server:callWagon', function() MW.CallWagon(source) end)
RegisterNetEvent('MULTIwagons:server:activateWagon', function(id) MW.Activate(source, id) end)
RegisterNetEvent('MULTIwagons:server:sellWagon', function(id) MW.Sell(source, id) end)
RegisterNetEvent('MULTIwagons:server:saveCustomization', function(id, customType, value) MW.SaveCustomization(source, id, customType, value) end)
RegisterNetEvent('MULTIwagons:server:registerWagon', function(netId, wagonID, model) MW.Register(source, netId, wagonID, model) end)
RegisterNetEvent('MULTIwagons:server:removeWagon', function(netId) MW.Remove(source, netId) end)
RegisterNetEvent('MULTIwagons:server:openStash', function(netId) MW.OpenStash(source, netId) end)
RegisterNetEvent('MULTIwagons:server:answerPermission', function(netId, requester, allow) MW.AnswerPermission(source, netId, requester, allow == true) end)
RegisterNetEvent('MULTIwagons:server:updateWagonAuth', function(netId, citizenID, action) MW.UpdateAuth(source, netId, citizenID, action) end)
RegisterNetEvent('MULTIwagons:server:storeAnimal', function(netId, animal) MW.StoreAnimal(source, netId, animal) end)
RegisterNetEvent('MULTIwagons:server:takeAnimal', function(wagonId, infos) MW.TakeAnimal(source, wagonId, infos) end)

lib.callback.register('MULTIwagons:server:myWagons', function(src) return MW.MyWagons(src) end)
lib.callback.register('MULTIwagons:server:isWagonRegistered', function(src, netId) return MW.IsRegistered(src, netId) end)
lib.callback.register('MULTIwagons:server:getAnimalStorage', function(_, wagonId) return MW.AnimalMenu(wagonId) end)

-- ------------------------------------------------------------
-- database and start
-- ------------------------------------------------------------

local SCHEMA = [[CREATE TABLE IF NOT EXISTS `rsg_wagons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL DEFAULT '0',
  `wagon` varchar(50) NOT NULL DEFAULT '0',
  `custom` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '{}',
  `animals` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '[]',
  `active` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- columns an older table may lack (added in this order)
local COLUMNS = {
    { 'citizenid', "varchar(50) NOT NULL DEFAULT '0'" },
    { 'wagon', "varchar(50) NOT NULL DEFAULT '0'" },
    { 'custom', "longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '{}'" },
    { 'animals', "longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '[]'" },
    { 'active', "int(11) NOT NULL DEFAULT 0" },
}

local function migrateColumns()
    local have = {}
    for _, row in ipairs(MySQL.query.await([[SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_wagons']]) or {}) do
        have[row.c] = true
    end
    for _, col in ipairs(COLUMNS) do
        if not have[col[1]] then
            -- MariaDB knows IF NOT EXISTS; MySQL does not, so a plain ADD is tried after it
            local ok = pcall(MySQL.query.await, ('ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `%s` %s'):format(col[1], col[2]))
            if not ok then pcall(MySQL.query.await, ('ALTER TABLE `rsg_wagons` ADD COLUMN `%s` %s'):format(col[1], col[2])) end
            print(('[MULTIwagons] column %s added to rsg_wagons'):format(col[1]))
        end
    end
    -- rows without JSON (from very old tables) get empty JSON
    MySQL.update.await("UPDATE rsg_wagons SET custom = '{}' WHERE custom IS NULL OR custom = ''")
    MySQL.update.await("UPDATE rsg_wagons SET animals = '[]' WHERE animals IS NULL OR animals = ''")
end

local function migrateStash(w)
    local old = 'stash:' .. OLD_STASH .. w.id
    local inv = MI:Exists(old)
    if not inv or type(inv.items) ~= 'table' then return 0 end
    local target, moved = MW.StorageId(w.custom.plate), 0
    for _, s in pairs(inv.items) do
        local ok = MI:AddItem(target, s.name, s.amount, s.info, nil, 'multiwagons-migrate')
        if ok then moved = moved + 1 else print(('^3[MULTIwagons] could not move %s x%s from %s^7'):format(s.name, s.amount, old)) end
    end
    MI:Save(target, true)
    MI:Delete(old)
    return moved
end

--- Rows without a storage id get one (and their old stash's items).
local function upgradeRows()
    local fixed = 0
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_wagons') or {}) do
        local w = decode(row)
        if not w.custom.plate then
            if not w.custom.name or w.custom.name == '' then
                local cfg = MW.ModelCfg(w.model)
                w.custom.name = cfg and cfg.name or w.model
            end
            if ensureStorage(w) then
                if Config.MigrateOldStashes then migrateStash(w) end
                fixed = fixed + 1
            end
        end
    end
    if fixed > 0 then print(('[MULTIwagons] %d wagons given a storage'):format(fixed)) end
end

CreateThread(function()
    math.randomseed(os.time())
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    MySQL.query.await(SCHEMA)
    migrateColumns()
    upgradeRows()
    MW.ready = true
    TriggerEvent('MULTIwagons:ready')
    print('^2[MULTIwagons] ready^7')
end)

-- storage left open by a player who walked away is closed
CreateThread(function()
    while true do
        Wait(5000)
        if Config.ServerDistanceCheck then
            for src, netId in pairs(MW.Viewing) do
                if not nearWagon(src, netId, Config.StorageServerDistance) then
                    MW.Viewing[src] = nil
                    pcall(function() MI:Close(src) end)
                end
            end
        end
    end
end)

local function onLeave(src)
    src = tonumber(src)
    if not src then return end
    MW.Viewing[src] = nil
    for netId, r in pairs(wagons) do
        if r.owner == src then
            if Config.DespawnOnLeave then despawn(netId) else r.owner = nil end
        end
    end
    for _, asks in pairs(MW.Asks) do asks[src] = nil end
end
AddEventHandler('RSGCore:Server:OnPlayerUnload', onLeave)
AddEventHandler('playerDropped', function() onLeave(source) end)

-- a deleted character's wagons and their storage go with it
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    for _, w in ipairs(MW.ListOf(citizenid)) do
        local _, netId = MW.OutById(w.id)
        if netId then despawn(netId) end
        wagonAnimalsData[w.id] = nil
        deleteStorage(w)
    end
    MySQL.update.await('DELETE FROM rsg_wagons WHERE citizenid = ?', { citizenid })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId in pairs(wagons) do
        local e = MW.Entity(netId)
        if e then DeleteEntity(e) end
    end
end)

-- ------------------------------------------------------------
-- exports (server-trusted: callers check their own rules)
-- ------------------------------------------------------------

local function pub(w)
    if not w then return nil end
    local r, netId = MW.OutById(w.id)
    local cfg = MW.ModelCfg(w.model)
    return {
        id = w.id, citizenid = w.citizenid, model = w.model, label = cfg and cfg.name or w.model,
        name = w.custom.name, plate = w.custom.plate, selected = w.active, out = r ~= nil, netId = netId,
        storage = w.custom.plate and MW.StorageId(w.custom.plate) or nil, custom = w.custom,
    }
end
MW.Public = pub

local function cidOf(srcOrCitizenId)
    return type(srcOrCitizenId) == 'string' and srcOrCitizenId or getCitizenId(srcOrCitizenId)
end

exports('IsReady', function() return MW.ready end)
exports('GetWagons', function(srcOrCitizenId)
    local out = {}
    for _, w in ipairs(MW.ListOf(cidOf(srcOrCitizenId))) do out[#out + 1] = pub(w) end
    return out
end)
exports('GetWagon', function(id) return pub(MW.Get(id)) end)
exports('GetWagonByPlate', function(plate)
    if type(plate) ~= 'string' then return nil end
    local row = MySQL.single.await("SELECT * FROM rsg_wagons WHERE custom LIKE ? LIMIT 1", { '%"plate":"' .. plate .. '"%' })
    return row and pub(decode(row)) or nil
end)
exports('GetActiveWagon', function(srcOrCitizenId)
    local cid = cidOf(srcOrCitizenId)
    for _, r in pairs(wagons) do
        if r.citizenid == cid then return pub(MW.Get(r.wagonID)) end
    end
end)
exports('GetWagonByNetId', function(netId)
    local r = wagons[tonumber(netId)]
    return r and pub(MW.Get(r.wagonID)) or nil
end)
exports('GetStorageId', function(idOrPlate)
    if tonumber(idOrPlate) then
        local w = MW.Get(idOrPlate)
        return w and w.custom.plate and MW.StorageId(w.custom.plate) or nil
    end
    return type(idOrPlate) == 'string' and MW.StorageId(idOrPlate) or nil
end)
exports('GetModelConfig', function(model) return MW.ModelCfg(model) end)
exports('OpenStorage', MW.OpenStorage)
exports('CallWagon', MW.CallWagon)
exports('Despawn', function(id)
    local _, netId = MW.OutById(id)
    if netId then despawn(netId) return true end
    return false
end)
