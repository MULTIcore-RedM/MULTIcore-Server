-- ============================================================
-- MULTIhorses :: server (part of MULTIcore, GPL v3)
-- Every change to money, items and horses is decided here. The client
-- only asks (lib.callback / events) and plays animations.
--
-- Tables: player_horses has rsg-horses' shape (RSG v2 framework, GPL v3,
-- installation/setup.sql), so RSG scripts that read or write it (starter
-- horses from rsg-multicharacter, RINGOwagons, RINGOitemplacer) keep working.
-- MULTIhorses' own extras (health, stamina, fallen, tack) live in
-- multihorses_state, keyed by the same horseid.
-- Saddlebags are MULTIinventory custom inventories 'custom:horse_<horseid>'.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

Horses = {
    ready = false,
    Out = {},        -- [src] = { horseid, netId, dead, test }
    Busy = {},       -- [src] = true while an action that charges money runs
    Rate = {},       -- [src] = { list of timestamps }
    CareAt = {},     -- [src] = GetGameTimer() of the last care action
    BrushAt = {},    -- [horseid] = os.time() of the last brushing that gave points
    SaveAt = {},     -- [src] = GetGameTimer() of the last state save
}

local function dbg(...)
    if Config.Debug then print('[MULTIhorses]', ...) end
end
Horses.dbg = dbg

local function notify(src, text, kind)
    if not GetPlayerName(src) then return end -- nobody there (a script or a self-test call)
    exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info' })
end
Horses.notify = notify

--- Tells the player what went wrong (err code -> locale 'err_<code>').
local function refuse(src, err, ...)
    if src and src > 0 then notify(src, _L('err_' .. tostring(err), ...), 'error') end
    dbg('refused', src, err)
    return false, err
end

local function getP(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end
local function cidOf(src) local P = getP(src); return P and P.PlayerData.citizenid or nil end
Horses.getP = getP

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function rateOk(src)
    local now = GetGameTimer()
    local list = Horses.Rate[src] or {}
    local keep = {}
    for _, t in ipairs(list) do if now - t < Config.RateLimit.WindowMs then keep[#keep + 1] = t end end
    if #keep >= Config.RateLimit.Calls then Horses.Rate[src] = keep return false end
    keep[#keep + 1] = now
    Horses.Rate[src] = keep
    return true
end

--- Runs fn while the player has no other money action running (no double clicks).
local function locked(src, fn)
    if Horses.Busy[src] then return false, 'busy' end
    Horses.Busy[src] = true
    local res = table.pack(pcall(fn))
    Horses.Busy[src] = nil
    if not res[1] then
        print(('^1[MULTIhorses] error: %s^7'):format(tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

-- ------------------------------------------------------------
-- database
-- ------------------------------------------------------------
local SCHEMA = {
    -- rsg-horses' table (installation/setup.sql, RSG v2 framework, GPL v3)
    [[CREATE TABLE IF NOT EXISTS `player_horses` (
      `id` INT(11) NOT NULL AUTO_INCREMENT,
      `stable` VARCHAR(50) NOT NULL DEFAULT 'valentine',
      `citizenid` VARCHAR(50) NOT NULL,
      `horseid` VARCHAR(6) NOT NULL,
      `name` VARCHAR(50) NOT NULL,
      `horse` VARCHAR(100) NOT NULL,
      `gender` VARCHAR(10) NOT NULL DEFAULT 'male',
      `active` TINYINT(1) NOT NULL DEFAULT 0,
      `born` INT(11) NOT NULL DEFAULT 0,
      `components` LONGTEXT DEFAULT NULL,
      `coat` LONGTEXT DEFAULT NULL,
      `horsexp` INT(11) NOT NULL DEFAULT 0,
      `dirt` INT(11) NOT NULL DEFAULT 0,
      `age_seconds` INT(11) NOT NULL DEFAULT 0,
      `pregnant_until` INT(11) DEFAULT NULL,
      `last_bred` INT(11) DEFAULT NULL,
      `stored_weapon` VARCHAR(100) DEFAULT NULL,
      `stored_weapon_name` VARCHAR(100) DEFAULT NULL,
      `stored_weapon_data` LONGTEXT DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY `idx_citizenid` (`citizenid`),
      KEY `idx_horseid` (`horseid`),
      KEY `idx_active` (`citizenid`, `active`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    -- MULTIhorses' own extras per horse
    [[CREATE TABLE IF NOT EXISTS `multihorses_state` (
      `horseid` VARCHAR(6) NOT NULL,
      `citizenid` VARCHAR(50) NOT NULL,
      `health` TINYINT UNSIGNED NOT NULL DEFAULT 100,
      `stamina` TINYINT UNSIGNED NOT NULL DEFAULT 100,
      `injured` TINYINT(1) NOT NULL DEFAULT 0,
      `tack` LONGTEXT DEFAULT NULL,
      PRIMARY KEY (`horseid`),
      KEY `idx_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local SELECT_HORSE = [[SELECT h.id, h.stable, h.citizenid, h.horseid, h.name, h.horse, h.gender, (h.active + 0) AS active, h.dirt,
    (COALESCE(s.health, 100) + 0) AS health, (COALESCE(s.stamina, 100) + 0) AS stamina, (COALESCE(s.injured, 0) + 0) AS injured, s.tack
    FROM player_horses h LEFT JOIN multihorses_state s ON s.horseid = h.horseid ]]

--- The database driver may hand computed / TINYINT(1) columns back as strings or booleans: make them numbers.
local function norm(row)
    if not row then return nil end
    for _, k in ipairs({ 'active', 'health', 'stamina', 'injured', 'dirt' }) do
        local v = row[k]
        if v == true then v = 1 elseif v == false then v = 0 end
        row[k] = math.floor(tonumber(v) or 0)
    end
    return row
end

--- All horses of a character (list, oldest first).
function Horses.List(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    local rows = MySQL.query.await(SELECT_HORSE .. 'WHERE h.citizenid = ? ORDER BY h.id', { citizenid }) or {}
    for _, r in ipairs(rows) do norm(r) end
    return rows
end

--- One horse of a character, by row id (number) or horseid (string).
function Horses.Find(citizenid, id)
    if type(citizenid) ~= 'string' then return nil end
    if tonumber(id) then
        return norm(MySQL.single.await(SELECT_HORSE .. 'WHERE h.citizenid = ? AND h.id = ? LIMIT 1', { citizenid, tonumber(id) }))
    elseif type(id) == 'string' then
        return norm(MySQL.single.await(SELECT_HORSE .. 'WHERE h.citizenid = ? AND h.horseid = ? LIMIT 1', { citizenid, id }))
    end
end

function Horses.Active(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    return norm(MySQL.single.await(SELECT_HORSE .. 'WHERE h.citizenid = ? AND h.active = 1 LIMIT 1', { citizenid }))
end

--- Makes the extras row when a horse has none (e.g. a starter horse another script inserted).
local function ensureState(horse)
    MySQL.prepare.await('INSERT IGNORE INTO multihorses_state (horseid, citizenid) VALUES (?, ?)', { horse.horseid, horse.citizenid })
end

local function newHorseId()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    for _ = 1, 50 do
        local id = ''
        for _ = 1, 3 do local i = math.random(1, #letters); id = id .. letters:sub(i, i) end
        id = id .. tostring(math.random(100, 999))
        if (MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE horseid = ?', { id }) or 0) == 0 then return id end
    end
    return nil
end

-- ------------------------------------------------------------
-- stables
-- ------------------------------------------------------------

--- Adds a stable from another server script: { id, label?, coords? (vector3), distance? }.
--- A stable without coords has no distance check (only server scripts can use it).
function Horses.RegisterStable(def)
    if type(def) ~= 'table' or type(def.id) ~= 'string' or def.id == '' then return false end
    MH.Stables[def.id] = { id = def.id, label = def.label, coords = def.coords, distance = def.distance, script = true }
    return true
end

function Horses.GetStable(id) return MH.Stables[id] end

local function nearStable(src, stable)
    if not stable then return false end
    if not stable.coords or not Config.ServerDistanceCheck then return true end
    local pos = pedCoords(src)
    if not pos then return false end
    return #(pos - stable.coords) <= (stable.distance or Config.StableDistance)
end
Horses.NearStable = nearStable

--- The config stable the player stands at (nil when none).
function Horses.StableAt(src)
    local pos = pedCoords(src)
    if not pos then return nil end
    for _, s in ipairs(Config.Stables) do
        if #(pos - s.coords) <= Config.StableDistance then return s end
    end
end

local function stableFor(src, stableId)
    local stable = MH.Stables[stableId]
    if not stable then return nil, 'bad_stable' end
    if not nearStable(src, stable) then return nil, 'too_far' end
    return stable
end

-- ------------------------------------------------------------
-- saddlebags
-- ------------------------------------------------------------
function Horses.BagId(horseid) return 'custom:horse_' .. tostring(horseid) end

local function bagSpec(horse)
    return { label = _L('saddlebag_label', horse.name), slots = Config.Saddlebag.Slots, maxWeight = Config.Saddlebag.MaxWeight }
end

function Horses.EnsureBag(horse)
    local id = Horses.BagId(horse.horseid)
    MI:Create(id, bagSpec(horse))
    return id
end

local function bagEmpty(horseid)
    local inv = MI:Exists(Horses.BagId(horseid))
    if not inv or type(inv.items) ~= 'table' then return true end
    return next(inv.items) == nil
end

-- ------------------------------------------------------------
-- the horse that is out (spawned by its owner's game)
-- ------------------------------------------------------------
local function outEntity(out)
    if not out or not out.netId or out.netId == 0 then return nil end
    local ent = NetworkGetEntityFromNetworkId(out.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

--- Is the player's horse out and within reach? mode: 'alive' | 'dead' | 'any'.
--- → true, out, entity | false, err ('no_horse', 'too_far', 'horse_dead', 'not_dead')
function Horses.HorseNear(src, mode)
    local out = Horses.Out[src]
    if not out then return false, 'no_horse' end
    local ent
    if not out.test and Config.ServerDistanceCheck then
        ent = outEntity(out)
        if not ent then return false, 'no_horse' end
        local pos = pedCoords(src)
        if not pos then return false, 'too_far' end
        if #(GetEntityCoords(ent) - pos) > Config.InteractDistance + 1.5 then return false, 'too_far' end
        if GetEntityHealth(ent) <= 0 then out.dead = true end
    end
    if mode == 'alive' and out.dead then return false, 'horse_dead' end
    if mode == 'dead' and not out.dead then return false, 'not_dead' end
    return true, out, ent
end

local function despawnFor(src)
    if Horses.Out[src] then TriggerClientEvent('MULTIhorses:client:despawn', src) end
    Horses.Out[src] = nil
end

-- ------------------------------------------------------------
-- buy / sell / active / store / transfer / rename / revive / tack
-- ------------------------------------------------------------

--- → true, { id, horseid } | false, err
function Horses.Buy(src, stableId, model, name, gender)
    src = tonumber(src)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local def = MH.HorseByModel[model]
    if not def or not MH.SoldAt(def, stableId) then return refuse(src, 'bad_horse') end
    name = MH.CleanName(name)
    if not name then return refuse(src, 'bad_name', Config.NameMinLength, Config.NameMaxLength) end
    gender = (Config.Genders and gender == 'female') and 'female' or 'male'
    local cid = P.PlayerData.citizenid

    return locked(src, function()
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE citizenid = ?', { cid }) or 0
        if count >= Config.MaxHorses then return refuse(src, 'limit', Config.MaxHorses) end
        local horseid = newHorseId()
        if not horseid then return refuse(src, 'error') end
        if not P.Functions.RemoveMoney(Config.Currency, def.price, 'horse-purchase') then
            return refuse(src, 'no_money', MH.Money(def.price))
        end
        local id = MySQL.insert.await('INSERT INTO player_horses (stable, citizenid, horseid, name, horse, gender, active, born) VALUES (?, ?, ?, ?, ?, ?, 0, ?)', {
            stable.id, cid, horseid, name, model, gender, os.time(),
        })
        if not id then
            P.Functions.AddMoney(Config.Currency, def.price, 'horse-purchase-refund')
            return refuse(src, 'error')
        end
        MySQL.insert.await('INSERT INTO multihorses_state (horseid, citizenid) VALUES (?, ?)', { horseid, cid })
        Horses.EnsureBag({ horseid = horseid, name = name })
        notify(src, _L('bought', name, MH.Money(def.price)), 'success')
        dbg('bought', src, cid, model, horseid, def.price)
        TriggerEvent('MULTIhorses:bought', src, horseid, model)
        return true, { id = id, horseid = horseid }
    end)
end

--- → true, paid | false, err
function Horses.Sell(src, id, stableId)
    src = tonumber(src)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local cid = P.PlayerData.citizenid
    return locked(src, function()
        local horse = Horses.Find(cid, id)
        if not horse then return refuse(src, 'not_owner') end
        if Config.Saddlebag.RequireEmptyToSell and not bagEmpty(horse.horseid) then return refuse(src, 'bag_not_empty') end
        -- delete first and only pay when this request removed the row
        local affected = MySQL.update.await('DELETE FROM player_horses WHERE id = ? AND citizenid = ?', { horse.id, cid })
        if affected ~= 1 then return refuse(src, 'not_owner') end
        MySQL.prepare.await('DELETE FROM multihorses_state WHERE horseid = ?', { horse.horseid })
        MI:Delete(Horses.BagId(horse.horseid))
        local out = Horses.Out[src]
        if out and out.horseid == horse.horseid then despawnFor(src) end
        local pay = MH.SellPrice(horse.horse)
        if pay > 0 then P.Functions.AddMoney(Config.Currency, pay, 'horse-sold') end
        notify(src, _L('sold', horse.name, MH.Money(pay)), 'success')
        dbg('sold', src, cid, horse.horseid, pay)
        TriggerEvent('MULTIhorses:sold', src, horse.horseid)
        return true, pay
    end)
end

--- Makes a horse the one that comes to the whistle.
function Horses.SetActive(src, id, stableId)
    src = tonumber(src)
    local cid = cidOf(src)
    if not cid then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local horse = Horses.Find(cid, id)
    if not horse then return refuse(src, 'not_owner') end
    if horse.injured == 1 then return refuse(src, 'injured', horse.name) end
    if Config.Transfer.Enabled and horse.stable ~= stable.id and horse.active ~= 1 then
        return refuse(src, 'not_here', horse.name, MH.StableLabel(horse.stable))
    end
    MySQL.update.await('UPDATE player_horses SET active = (id = ?) WHERE citizenid = ?', { horse.id, cid })
    local out = Horses.Out[src]
    if out and out.horseid ~= horse.horseid then despawnFor(src) end
    notify(src, _L('set_active', horse.name), 'success')
    return true
end

--- Puts the active horse in this stable.
function Horses.Store(src, stableId)
    src = tonumber(src)
    local cid = cidOf(src)
    if not cid then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local horse = Horses.Active(cid)
    if not horse then return refuse(src, 'no_active') end
    MySQL.update.await('UPDATE player_horses SET active = 0, stable = ? WHERE id = ?', { stable.id, horse.id })
    despawnFor(src)
    notify(src, _L('stored', horse.name, MH.StableLabel(stable.id)), 'success')
    return true
end

--- Brings a horse to the stable the player stands at (or, rsg-horses style, sends it from there).
function Horses.Transfer(src, id, toStableId, fromStableId)
    src = tonumber(src)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not Config.Transfer.Enabled then return refuse(src, 'no_transfer') end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local to = MH.Stables[toStableId]
    if not to then return refuse(src, 'bad_stable') end
    local cid = P.PlayerData.citizenid
    return locked(src, function()
        local horse = Horses.Find(cid, id)
        if not horse then return refuse(src, 'not_owner') end
        if horse.active == 1 then return refuse(src, 'is_active', horse.name) end
        if horse.stable == to.id then return refuse(src, 'already_here', horse.name) end
        -- the player stands at the destination, or at the stable the horse is in
        local from = MH.Stables[fromStableId or horse.stable]
        if not nearStable(src, to) and not (from and from.id == horse.stable and nearStable(src, from)) then
            return refuse(src, 'too_far')
        end
        local fee = MH.TransferFee(horse.stable, to.id)
        if fee > 0 and not P.Functions.RemoveMoney(Config.Currency, fee, 'horse-transfer') then
            return refuse(src, 'no_money', MH.Money(fee))
        end
        MySQL.update.await('UPDATE player_horses SET stable = ? WHERE id = ?', { to.id, horse.id })
        notify(src, _L('transferred', horse.name, MH.StableLabel(to.id), MH.Money(fee)), 'success')
        return true, fee
    end)
end

function Horses.Rename(src, id, name)
    src = tonumber(src)
    local cid = cidOf(src)
    if not cid then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    name = MH.CleanName(name)
    if not name then return refuse(src, 'bad_name', Config.NameMinLength, Config.NameMaxLength) end
    local horse = Horses.Find(cid, id)
    if not horse then return refuse(src, 'not_owner') end
    MySQL.update.await('UPDATE player_horses SET name = ? WHERE id = ?', { name, horse.id })
    MI:Create(Horses.BagId(horse.horseid), bagSpec({ horseid = horse.horseid, name = name }))
    local out = Horses.Out[src]
    if out and out.horseid == horse.horseid then TriggerClientEvent('MULTIhorses:client:renamed', src, name) end
    notify(src, _L('renamed', name), 'success')
    return true
end

--- The stable nurses a fallen horse back for a fee.
function Horses.ReviveAtStable(src, id, stableId)
    src = tonumber(src)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local cid = P.PlayerData.citizenid
    return locked(src, function()
        local horse = Horses.Find(cid, id)
        if not horse then return refuse(src, 'not_owner') end
        if horse.injured ~= 1 then return refuse(src, 'not_injured', horse.name) end
        local out = Horses.Out[src]
        if out and out.horseid == horse.horseid then return refuse(src, 'body_out', horse.name) end
        local fee = MH.Cents(Config.Revive.StableFee)
        if fee > 0 and not P.Functions.RemoveMoney(Config.Currency, fee, 'horse-vet') then
            return refuse(src, 'no_money', MH.Money(fee))
        end
        ensureState(horse)
        MySQL.update.await('UPDATE multihorses_state SET injured = 0, health = ?, stamina = ? WHERE horseid = ?',
            { Config.Revive.Health, Config.Revive.Health, horse.horseid })
        notify(src, _L('vet_done', horse.name, MH.Money(fee)), 'success')
        return true, fee
    end)
end

--- Puts a tack piece on (index into the category's items) or takes it off (index 0).
function Horses.SetTack(src, id, catKey, index, stableId)
    src = tonumber(src)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not Config.Tack.Enabled then return refuse(src, 'no_tack') end
    if not rateOk(src) then return refuse(src, 'slow_down') end
    local cat = MH.TackByKey[catKey]
    index = tonumber(index)
    if not cat or not index or index < 0 or index > #cat.items or index ~= math.floor(index) then return refuse(src, 'bad_tack') end
    local stable, err = stableFor(src, stableId)
    if not stable then return refuse(src, err) end
    local cid = P.PlayerData.citizenid
    return locked(src, function()
        local horse = Horses.Find(cid, id)
        if not horse then return refuse(src, 'not_owner') end
        local tack = MH.DecodeTack(horse.tack)
        local item = cat.items[index]
        local price = 0
        if item then
            if tack[cat.key] == item.hash then return refuse(src, 'tack_same') end
            price = MH.Cents(item.price)
            if price > 0 and not P.Functions.RemoveMoney(Config.Currency, price, 'horse-tack') then
                return refuse(src, 'no_money', MH.Money(price))
            end
            tack[cat.key] = item.hash
        else
            tack[cat.key] = nil
        end
        ensureState(horse)
        MySQL.update.await('UPDATE multihorses_state SET tack = ? WHERE horseid = ?', { json.encode(tack), horse.horseid })
        local out = Horses.Out[src]
        if out and out.horseid == horse.horseid then TriggerClientEvent('MULTIhorses:client:tack', src, tack) end
        if item then
            notify(src, _L('tack_bought', _L(item.label), MH.Money(price)), 'success')
        else
            notify(src, _L('tack_removed', _L(cat.label)), 'success')
        end
        return true, price
    end)
end

-- ------------------------------------------------------------
-- calling, state, death
-- ------------------------------------------------------------

--- What the client needs to spawn the active horse. → data | nil, err
function Horses.CallData(src)
    local cid = cidOf(src)
    if not cid then return nil, 'no_player' end
    local horse = Horses.Active(cid)
    if not horse then return nil, 'no_active' end
    if horse.injured == 1 and not (Horses.Out[src] and Horses.Out[src].horseid == horse.horseid) then
        return nil, 'injured', horse.name
    end
    return {
        horseid = horse.horseid, name = horse.name, model = horse.horse, gender = horse.gender,
        health = horse.health, stamina = horse.stamina, dirt = horse.dirt, tack = MH.DecodeTack(horse.tack),
    }
end

-- the owner's game spawned the horse: remember its network id
RegisterNetEvent('MULTIhorses:server:spawned', function(netId)
    local src = source
    local cid = cidOf(src)
    netId = tonumber(netId)
    if not cid or not netId then return end
    local horse = Horses.Active(cid)
    if not horse or horse.injured == 1 then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        if GetEntityModel(ent) ~= joaat(horse.horse) then return dbg('spawned: wrong model from', src) end
        Entity(ent).state:set('multihorse', horse.horseid, true)       -- set by the server: other scripts can trust it
        Entity(ent).state:set('rsgHorseOwner', true, true)              -- rsg-horses' flag ("not a wild horse")
    elseif Config.ServerDistanceCheck then
        return dbg('spawned: no entity for net id', netId, 'from', src)
    end
    Horses.Out[src] = { horseid = horse.horseid, netId = netId, dead = false }
    TriggerEvent('MULTIhorses:spawned', src, horse.horseid, netId)
end)

-- the horse is gone from the world (sent away, stored, body taken in)
RegisterNetEvent('MULTIhorses:server:despawned', function()
    Horses.Out[source] = nil
end)

local function clampCore(v)
    v = math.floor(tonumber(v) or -1)
    if v < 0 or v > 100 then return nil end
    return v
end

--- Saves the health / stamina cores of the horse that is out (sent by its owner's game).
function Horses.SaveState(src, health, stamina)
    local out = Horses.Out[src]
    if not out or out.dead then return false end
    health, stamina = clampCore(health), clampCore(stamina)
    if not health or not stamina then return false end
    MySQL.prepare('UPDATE multihorses_state SET health = ?, stamina = ? WHERE horseid = ? AND injured = 0', { health, stamina, out.horseid })
    return true
end

RegisterNetEvent('MULTIhorses:server:state', function(health, stamina)
    local src = source
    local now = GetGameTimer()
    if Horses.SaveAt[src] and now - Horses.SaveAt[src] < 5000 then return end
    Horses.SaveAt[src] = now
    Horses.SaveState(src, health, stamina)
end)

--- The horse that is out has fallen: it can be revived with the item for a while, else at a stable.
function Horses.Died(src)
    local out = Horses.Out[src]
    if not out or out.dead then return false end
    if not out.test and Config.ServerDistanceCheck then
        local ent = outEntity(out)
        if ent and GetEntityHealth(ent) > 0 then return false end
    end
    out.dead = true
    MySQL.prepare.await('UPDATE multihorses_state SET injured = 1, health = 0 WHERE horseid = ?', { out.horseid })
    local cid = cidOf(src)
    local horse = cid and Horses.Find(cid, out.horseid)
    if horse then notify(src, _L('horse_fell', horse.name, MH.Money(Config.Revive.StableFee)), 'error') end
    dbg('horse fell', src, out.horseid)
    TriggerEvent('MULTIhorses:died', src, out.horseid)
    return true
end

RegisterNetEvent('MULTIhorses:server:died', function() Horses.Died(source) end)

-- ------------------------------------------------------------
-- care: feed, brush, reviver, lantern, saddlebags
-- ------------------------------------------------------------
local function careReady(src)
    local now = GetGameTimer()
    if Horses.CareAt[src] and now - Horses.CareAt[src] < Config.CareCooldownMs then return false end
    return true
end

local function careDone(src) Horses.CareAt[src] = GetGameTimer() end

--- Feeds the horse that is out. itemName nil = the first food in Config.Feed the player carries.
function Horses.Feed(src, itemName, slot)
    src = tonumber(src)
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not careReady(src) then return false, 'busy' end
    local ok, out = Horses.HorseNear(src, 'alive')
    if not ok then return refuse(src, out) end
    local def
    if itemName then
        def = MH.FeedByItem[itemName]
        if not def or (MI:Count(pid, itemName) or 0) < 1 then return refuse(src, 'no_food') end
    else
        for _, f in ipairs(Config.Feed) do
            if (MI:Count(pid, f.item) or 0) > 0 then def = f break end
        end
        if not def then return refuse(src, 'no_food') end
        slot = nil
    end
    if not MI:RemoveItem(pid, def.item, 1, slot) then return refuse(src, 'no_food') end
    careDone(src)
    MySQL.prepare('UPDATE multihorses_state SET health = LEAST(100, health + ?), stamina = LEAST(100, stamina + ?) WHERE horseid = ?',
        { def.health or 0, def.stamina or 0, out.horseid })
    TriggerClientEvent('MULTIhorses:client:feed', src, def.item, def.health or 0, def.stamina or 0, def.heal == true)
    return true, def.item
end

function Horses.Brush(src)
    src = tonumber(src)
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not careReady(src) then return false, 'busy' end
    if (MI:Count(pid, Config.Brush.Item) or 0) < 1 then return refuse(src, 'no_brush') end
    local ok, out = Horses.HorseNear(src, 'alive')
    if not ok then return refuse(src, out) end
    careDone(src)
    local points = 0
    local last = Horses.BrushAt[out.horseid]
    if not last or os.time() - last >= Config.Brush.CooldownSeconds then
        points = Config.Brush.Stamina
        Horses.BrushAt[out.horseid] = os.time()
        MySQL.prepare('UPDATE multihorses_state SET stamina = LEAST(100, stamina + ?) WHERE horseid = ?', { points, out.horseid })
    end
    TriggerClientEvent('MULTIhorses:client:brush', src, points)
    return true, points
end

--- Uses a reviver on the fallen horse beside the player.
function Horses.ReviveWithItem(src, slot)
    src = tonumber(src)
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not careReady(src) then return false, 'busy' end
    if (MI:Count(pid, Config.Revive.Item) or 0) < 1 then return refuse(src, 'no_reviver') end
    local ok, out = Horses.HorseNear(src, 'dead')
    if not ok then return refuse(src, out) end
    if not MI:RemoveItem(pid, Config.Revive.Item, 1, slot) then return refuse(src, 'no_reviver') end
    careDone(src)
    out.dead = false
    MySQL.prepare.await('UPDATE multihorses_state SET injured = 0, health = ?, stamina = ? WHERE horseid = ?',
        { Config.Revive.Health, Config.Revive.Health, out.horseid })
    TriggerClientEvent('MULTIhorses:client:revive', src, Config.Revive.Health)
    return true
end

function Horses.Lantern(src)
    src = tonumber(src)
    local pid = MI:PlayerInv(src)
    if not pid or Config.Lantern.Item == '' then return false, 'no_player' end
    if (MI:Count(pid, Config.Lantern.Item) or 0) < 1 then return refuse(src, 'no_lantern') end
    local ok, err = Horses.HorseNear(src, 'alive')
    if not ok then return refuse(src, err) end
    TriggerClientEvent('MULTIhorses:client:lantern', src)
    return true
end

--- Opens the saddlebags of the player's horse that is out and beside them.
function Horses.OpenSaddlebag(src)
    src = tonumber(src)
    local cid = cidOf(src)
    if not cid then return false, 'no_player' end
    local ok, out, ent = Horses.HorseNear(src, 'any')
    if not ok then return refuse(src, out) end
    local horse = Horses.Find(cid, out.horseid)
    if not horse then return refuse(src, 'no_horse') end
    local id = Horses.EnsureBag(horse)
    local spec = bagSpec(horse)
    if ent then spec.coords = GetEntityCoords(ent) end
    local opened, err = MI:Open(src, id, spec)
    if not opened then return false, err end
    return true, id
end

-- ------------------------------------------------------------
-- net requests from the client
-- ------------------------------------------------------------
lib.callback.register('MULTIhorses:callHorse', function(src) return Horses.CallData(src) end)

lib.callback.register('MULTIhorses:stableData', function(src, stableId)
    local cid = cidOf(src)
    if not cid or not MH.Stables[stableId] then return nil end
    local list = {}
    local out = Horses.Out[src]
    for _, h in ipairs(Horses.List(cid)) do
        list[#list + 1] = {
            id = h.id, horseid = h.horseid, name = h.name, model = h.horse, gender = h.gender, stable = h.stable,
            active = h.active == 1, injured = h.injured == 1, out = out ~= nil and out.horseid == h.horseid,
            tack = MH.DecodeTack(h.tack),
        }
    end
    return { horses = list, max = Config.MaxHorses }
end)

local ACTIONS = {
    buy = function(src, a) return Horses.Buy(src, a.stable, a.model, a.name, a.gender) end,
    sell = function(src, a) return Horses.Sell(src, a.id, a.stable) end,
    active = function(src, a) return Horses.SetActive(src, a.id, a.stable) end,
    store = function(src, a) return Horses.Store(src, a.stable) end,
    transfer = function(src, a) return Horses.Transfer(src, a.id, a.stable) end,
    rename = function(src, a)
        if not nearStable(src, MH.Stables[a.stable]) then return refuse(src, 'too_far') end
        return Horses.Rename(src, a.id, a.name)
    end,
    vet = function(src, a) return Horses.ReviveAtStable(src, a.id, a.stable) end,
    tack = function(src, a) return Horses.SetTack(src, a.id, a.category, a.index, a.stable) end,
    feed = function(src) return Horses.Feed(src) end,
    brush = function(src) return Horses.Brush(src) end,
    revive = function(src) return Horses.ReviveWithItem(src) end,
    saddlebag = function(src) return Horses.OpenSaddlebag(src) end,
    lantern = function(src) return Horses.Lantern(src) end,
}

lib.callback.register('MULTIhorses:action', function(src, action, args)
    local fn = ACTIONS[action]
    if not fn or (args ~= nil and type(args) ~= 'table') then return false, 'bad_request' end
    local ok, res = fn(src, args or {})
    return ok == true, res
end)

-- ------------------------------------------------------------
-- items
-- ------------------------------------------------------------
local function registerItems()
    local added, usable = 0, 0
    for name, def in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) and MI:RegisterItem(def) then added = added + 1 end
    end
    local function reg(name, fn)
        if name and name ~= '' and MI:GetItemDef(name) then
            -- built-in: a script that already handles the item (a premium stable script) keeps it
            MI:RegisterUsable(name, fn, { builtin = true, face = 'multi' })
            usable = usable + 1
        end
    end
    for _, f in ipairs(Config.Feed) do
        reg(f.item, function(src, stack) Horses.Feed(src, stack.name, stack.slot) end)
    end
    reg(Config.Brush.Item, function(src) Horses.Brush(src) end)
    reg(Config.Revive.Item, function(src, stack) Horses.ReviveWithItem(src, stack.slot) end)
    reg(Config.Lantern.Item, function(src) Horses.Lantern(src) end)
    print(('[MULTIhorses] %d items added to the registry, %d items usable'):format(added, usable))
end

-- ------------------------------------------------------------
-- start, players leaving, characters deleted
-- ------------------------------------------------------------
CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    for _, q in ipairs(SCHEMA) do MySQL.query.await(q) end
    local t = 0
    while (GetResourceState('MULTIinventory') ~= 'started' or not MI:IsReady()) and t < 1200 do Wait(250) t = t + 1 end
    if GetResourceState('MULTIinventory') == 'started' then
        registerItems()
    else
        print('^1[MULTIhorses] MULTIinventory is not running: no horse items, no saddlebags^7')
    end
    if Config.SellBack > 0.5 then print('^3[MULTIhorses] Config.SellBack is above 0.5; stables pay half the price at most^7') end
    Horses.ready = true
    TriggerEvent('MULTIhorses:ready')
end)

-- MULTIinventory restarted: its usable list is empty again
AddEventHandler('onResourceStart', function(res)
    if res ~= 'MULTIinventory' or not Horses.ready then return end
    CreateThread(function()
        local t = 0
        while not MI:IsReady() and t < 400 do Wait(250) t = t + 1 end
        registerItems()
    end)
end)

local function forget(src)
    Horses.Out[src] = nil
    Horses.Busy[src] = nil
    Horses.Rate[src] = nil
    Horses.CareAt[src] = nil
    Horses.SaveAt[src] = nil
end
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) forget(tonumber(src) or source) end)

-- MULTIcore deletes the player_horses rows; the extras and the saddlebags go here
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local rows = MySQL.query.await('SELECT horseid FROM multihorses_state WHERE citizenid = ?', { citizenid }) or {}
    for _, r in ipairs(rows) do MI:Delete(Horses.BagId(r.horseid)) end
    MySQL.prepare('DELETE FROM multihorses_state WHERE citizenid = ?', { citizenid })
end)

-- ------------------------------------------------------------
-- commands
-- ------------------------------------------------------------
if Config.Commands.FindHorse ~= '' then
    RegisterCommand(Config.Commands.FindHorse, function(src)
        local cid = cidOf(src)
        if not cid then return end
        local list = Horses.List(cid)
        if #list == 0 then return notify(src, _L('no_horses'), 'info') end
        for _, h in ipairs(list) do
            local where = h.active == 1 and _L('with_you') or MH.StableLabel(h.stable)
            notify(src, _L('find_line', h.name, where), h.injured == 1 and 'warning' or 'info')
        end
    end, false)
end

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('IsReady', function() return Horses.ready end)
exports('Buy', Horses.Buy)
exports('Sell', Horses.Sell)
exports('SetActive', Horses.SetActive)
exports('Store', Horses.Store)
exports('Transfer', Horses.Transfer)
exports('Rename', Horses.Rename)
exports('ReviveAtStable', Horses.ReviveAtStable)
exports('SetTack', Horses.SetTack)
exports('Feed', Horses.Feed)
exports('Brush', Horses.Brush)
exports('ReviveWithItem', Horses.ReviveWithItem)
exports('OpenSaddlebag', Horses.OpenSaddlebag)
exports('SaddlebagId', Horses.BagId)
exports('RegisterStable', Horses.RegisterStable)
exports('GetStable', Horses.GetStable)
exports('SellPrice', MH.SellPrice)
exports('GetHorses', function(srcOrCid)
    local cid = type(srcOrCid) == 'string' and srcOrCid or cidOf(srcOrCid)
    return Horses.List(cid)
end)
exports('GetActiveHorse', function(srcOrCid)
    local cid = type(srcOrCid) == 'string' and srcOrCid or cidOf(srcOrCid)
    return Horses.Active(cid)
end)
exports('GetHorseOut', function(src)
    local out = Horses.Out[tonumber(src)]
    if not out then return nil end
    return { horseid = out.horseid, netId = out.netId, dead = out.dead }
end)

-- test hooks (only with setr multicore_selftest true): a pretend horse "out" for a pretend player
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestSetOut', function(src, horseid, dead)
        if horseid == nil then Horses.Out[src] = nil return true end
        Horses.Out[src] = { horseid = horseid, netId = 0, dead = dead == true, test = true }
        Horses.CareAt[src] = nil
        return true
    end)
    exports("_TestReset", function(src)
        Horses.Rate[src], Horses.Busy[src], Horses.CareAt[src] = nil, nil, nil
        for k in pairs(Horses.BrushAt) do Horses.BrushAt[k] = nil end
        return true
    end)
end
