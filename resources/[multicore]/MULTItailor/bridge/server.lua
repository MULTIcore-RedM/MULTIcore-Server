-- ============================================================
-- MULTItailor framework bridge :: server
--
-- RSG mode  : MBridge.Core / MBridge.INV are small emulations of the
--             VORP-shaped calls the rest of the resource makes,
--             implemented on rsg-core (on MULTIcore: its RSG face).
--             With Config.Inventory = 'multi' MBridge.INV is the
--             MULTIinventory proxy (shared.lua).
-- VORP mode : MBridge.Core / MBridge.INV are vorp_core's core object
--             and vorp_inventory's exports (not used on MULTIcore).
--
-- Requires (loaded before this file): shared.lua and
-- '@oxmysql/lib/MySQL.lua'.
-- ============================================================

local RES = MBridge.Resource

-- ------------------------------------------------------------
-- Table renames on start (none for this resource; kept so the id map
-- below can take over an older table name).
-- ------------------------------------------------------------
local LEGACY_TABLES = {}

local function newNameOf(old)
    return 'multi_' .. old
end

local function tableExists(name)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    return (tonumber(n) or 0) > 0
end

---Rename `old` to `new` if `old` exists and `new` does not. Returns true if renamed.
local function renameLegacyTable(old, new)
    if not tableExists(old) then return false end
    if tableExists(new) then
        print(('^3[%s] both `%s` and `%s` exist - leaving the old one alone. Merge or drop it by hand.^7')
            :format(RES, old, new))
        return false
    end
    MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(old, new))
    print(('^2[%s] renamed table `%s` -> `%s` (existing data kept)^7'):format(RES, old, new))
    return true
end

local migration -- nil = not started, promise = running, true = done

---Idempotent and safe to call from several threads: later callers wait for the first.
function MBridge.MigrateLegacyTables()
    if migration == true then return end
    if migration then Citizen.Await(migration); return end
    local p = promise.new()
    migration = p
    local ok, err = pcall(function()
        for _, old in ipairs(LEGACY_TABLES[RES] or {}) do renameLegacyTable(old, newNameOf(old)) end
    end)
    if not ok then print(('^1[%s] legacy table migration failed: %s^7'):format(RES, tostring(err))) end
    migration = true
    p:resolve(true)
end

-- ------------------------------------------------------------
-- VORP: straight passthrough
-- ------------------------------------------------------------
if MBridge.IsVorp then
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and core then
        MBridge.Core = core
    else
        -- vorp_core not up yet (start order): resolve on first use.
        local cached
        MBridge.Core = setmetatable({}, { __index = function(_, k)
            if not cached then cached = exports.vorp_core:GetCore() end
            return cached[k]
        end })
    end
    MBridge.INV = MBridge.SelectINV(exports.vorp_inventory) -- MULTIinventory proxy when MBridge.IsMultiInv

    function MBridge.OnCharacterSelected(handler)
        AddEventHandler('vorp:SelectedCharacter', handler)
    end

    function MBridge.RegisterItems() end -- VORP items live in the `items` table (see sql/)
    return
end

-- ------------------------------------------------------------
-- RSG
-- ------------------------------------------------------------
local RSGCoreObj
local function RSG()
    if not RSGCoreObj then RSGCoreObj = exports['rsg-core']:GetCoreObject() end
    return RSGCoreObj
end

AddEventHandler('onResourceStart', function(res)
    if res == 'rsg-core' then RSGCoreObj = nil end
end)
-- GetCoreObject hands out a COPY; rsg-core fires this when Shared.Items / Jobs /
-- Gangs change at runtime (exports AddItem/AddJob...), so take a fresh copy.
AddEventHandler('RSGCore:Server:UpdateObject', function() RSGCoreObj = nil end)

local function INVX() return exports['rsg-inventory'] end

---Call the first rsg-inventory export of `names` that exists (current names first,
---then the legacy compat names), pcall-protected. Returns ok, result.
local function invCall(names, ...)
    local inv = INVX()
    for _, nm in ipairs(names) do
        local ok, res = pcall(function(...) return inv[nm](inv, ...) end, ...)
        if ok then return true, res end
    end
    return false, nil
end

---Write an item's info by SLOT (SetItemInfo); legacy SetItemData only takes a name
---and would hit the first stack of that name, so it is only the fallback.
local function setSlotInfo(src, it, info)
    local ok, res = invCall({ 'SetItemInfo' }, src, it.slot, info)
    if ok then return res ~= false end
    ok, res = invCall({ 'SetItemData' }, src, it.name, 'info', info, it.slot)
    return ok and res ~= false
end

local function getPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    return RSG().Functions.GetPlayer(src)
end

-- VORP names weapons WEAPON_XXX, RSG keeps every item name lower case.
local function rn(name)
    if type(name) == 'string' and name:find('^WEAPON_') then return name:lower() end
    return name
end
local function vn(name)
    if type(name) == 'string' and name:find('^weapon_') then return name:upper() end
    return name
end

local function tablesMatch(have, want)
    if type(want) ~= 'table' then return true end
    for k, v in pairs(want) do
        if have == nil or have[k] ~= v then return false end
    end
    return true
end

-- ------------------------------------------------------------
-- Character ids. VORP keys everything on a numeric charidentifier;
-- rsg-core keys on a string citizenid. Tables that store a number get
-- RSG citizenids mapped to a stable number in one small shared table
-- (created on demand; MULTIinventory uses the same table).
-- ------------------------------------------------------------
local MAP_TABLE = 'multiinv_rsg_characters'
local byCitizen, byId = {}, {}
local mapTableReady = false

local function ensureMapTable()
    if mapTableReady then return end
    -- shared with other resources (MULTIinventory uses the same map)
    MySQL.query.await(([[CREATE TABLE IF NOT EXISTS `%s` (
        `charidentifier` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
        PRIMARY KEY (`charidentifier`),
        UNIQUE KEY `uq_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(MAP_TABLE))
    mapTableReady = true
end

---citizenid -> numeric charidentifier (yields on first sight of a citizen).
function MBridge.CharIdOf(citizenid)
    if not citizenid then return nil end
    local id = byCitizen[citizenid]
    if id then return id end
    ensureMapTable()
    MySQL.query.await(('INSERT IGNORE INTO `%s` (`citizenid`) VALUES (?)'):format(MAP_TABLE), { citizenid })
    id = MySQL.scalar.await(('SELECT `charidentifier` FROM `%s` WHERE `citizenid` = ?'):format(MAP_TABLE), { citizenid })
    id = tonumber(id)
    if id then byCitizen[citizenid] = id; byId[id] = citizenid end
    return id
end

---numeric charidentifier -> citizenid (nil if never seen).
function MBridge.CitizenOf(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    local cid = byId[charId]
    if cid then return cid end
    ensureMapTable()
    cid = MySQL.scalar.await(('SELECT `citizenid` FROM `%s` WHERE `charidentifier` = ?'):format(MAP_TABLE), { charId })
    if cid then byCitizen[cid] = charId; byId[charId] = cid end
    return cid
end

-- ------------------------------------------------------------
-- Character / user objects (what Core.getUser(src) hands back)
-- ------------------------------------------------------------
local CURRENCY = { [0] = 'cash', [1] = 'gold', [2] = 'bloodmoney' }

local function ageFromBirthdate(bd)
    local y = tostring(bd or ''):match('(%d%d%d%d)')
    if not y then return nil end
    return tonumber(os.date('%Y')) - tonumber(y)
end

local function makeChar(src)
    local Player = getPlayer(src)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid
    local char = {
        source     = src,
        citizenid  = citizenid,
        identifier = Player.PlayerData.license,
    }
    -- charIdentifier is resolved on first read (it may need a DB round trip),
    -- so resources that never look at it never pay for it.
    local charId

    function char.addCurrency(currency, amount)
        local p = getPlayer(src)
        if not p or not amount or amount <= 0 then return false end
        if amount ~= amount or amount == math.huge then return false end -- nan guard
        -- returns whether the money was really added
        return p.Functions.AddMoney(CURRENCY[currency] or 'cash', amount, RES) and true or false
    end

    function char.removeCurrency(currency, amount)
        local p = getPlayer(src)
        if not p or not amount or amount <= 0 then return false end
        if amount ~= amount or amount == math.huge then return false end -- nan guard
        -- returns whether the money was really taken (false = not enough / refused)
        return p.Functions.RemoveMoney(CURRENCY[currency] or 'cash', amount, RES) and true or false
    end

    local live = {
        firstname = function(d) return d.charinfo and d.charinfo.firstname end,
        lastname  = function(d) return d.charinfo and d.charinfo.lastname end,
        gender    = function(d) return d.charinfo and d.charinfo.gender end,
        age       = function(d) return d.charinfo and ageFromBirthdate(d.charinfo.birthdate) end,
        money     = function(d) return d.money and d.money.cash or 0 end,
        gold      = function(d) return d.money and d.money.gold or 0 end,
        rol       = function(d) return d.money and d.money.bloodmoney or 0 end,
        job       = function(d) return d.job and d.job.name end,
        jobLabel  = function(d) return d.job and d.job.label end,
        jobGrade  = function(d) return d.job and d.job.grade and d.job.grade.level end,
    }
    return setmetatable(char, { __index = function(_, k)
        if k == 'charIdentifier' then
            if not charId then charId = MBridge.CharIdOf(citizenid) end
            return charId
        end
        local read = live[k]
        if not read then return nil end
        local p = getPlayer(src)
        return p and read(p.PlayerData) or nil
    end })
end

local function makeUser(src)
    local char = makeChar(src)
    if not char then return nil end
    local user = { source = src, getUsedCharacter = char }
    -- rsg-core admin = ace groups 'admin' / 'god' (RSGCore.Functions.HasPermission)
    local isAdmin = IsPlayerAceAllowed(src, 'command')
    if not isAdmin then
        local ok, res = pcall(function() return RSG().Functions.HasPermission(src, { 'god', 'admin' }) end)
        isAdmin = ok and res == true
    end
    user.getGroup = isAdmin and 'admin' or 'user'
    user.group    = user.getGroup
    return user
end

-- ------------------------------------------------------------
-- Notifications (rsg-core notifies through ox_lib)
-- ------------------------------------------------------------
local function notify(src, text, ms, ntype, title)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = title,
        description = tostring(text or ''),
        type        = ntype or 'inform',
        duration    = ms or 4000,
        position    = 'top-right',
    })
end

-- ------------------------------------------------------------
-- Callbacks: bridge-owned so they do not depend on rsg-core internals.
-- Register(name, fn(source, cb, ...))  /  TriggerAwait(name, source, ...)
-- (the server may also ask a client callback registered with the same
-- Register on the client side).
-- ------------------------------------------------------------
local Callbacks, pending, nextReq = {}, {}, 0
local EV_REQ_S, EV_RES_S = RES .. ':shb:sv:req', RES .. ':shb:sv:res'
local EV_REQ_C, EV_RES_C = RES .. ':shb:cl:req', RES .. ':shb:cl:res'

RegisterNetEvent(EV_REQ_S, function(id, name, ...)
    local src = source
    local fn = Callbacks[name]
    if not fn then
        TriggerClientEvent(EV_RES_C, src, id)
        return
    end
    fn(src, function(...) TriggerClientEvent(EV_RES_C, src, id, ...) end, ...)
end)

RegisterNetEvent(EV_RES_S, function(id, ...)
    local e = pending[id]
    -- only the player we asked may answer (request ids are guessable)
    if e and e.src == source then pending[id] = nil; e.p:resolve(table.pack(...)) end
end)

local Callback = {}
function Callback.Register(name, fn) Callbacks[name] = fn end

function Callback.TriggerAwait(name, src, ...)
    nextReq = nextReq + 1
    local id = nextReq
    local p = promise.new()
    pending[id] = { p = p, src = tonumber(src) }
    SetTimeout(15000, function()
        if pending[id] then pending[id] = nil; p:resolve(table.pack()) end
    end)
    TriggerClientEvent(EV_REQ_C, src, id, name, ...)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

-- ------------------------------------------------------------
-- The Core shim
-- ------------------------------------------------------------
local Core = {
    Callback = Callback,
    getUser  = function(src) return makeUser(src) end,
}

function Core.getUserByCharId(charId)
    local citizenid = MBridge.CitizenOf(charId)
    if not citizenid then return nil end
    local Player = RSG().Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return nil end
    return makeUser(Player.PlayerData.source)
end

function Core.NotifyRightTip(src, text, ms)  notify(src, text, ms) end
function Core.NotifyTip(src, text, ms)       notify(src, text, ms) end
function Core.NotifyLeft(src, title, text, _, _, ms) notify(src, text, ms, 'inform', title) end
function Core.NotifyObjective(src, text, ms) notify(src, text, ms) end
function Core.NotifyAvanced(src, text, _, _, _, ms) notify(src, text, ms) end

Core.Player = {
    Revive = function(src) TriggerClientEvent('rsg-medic:client:adminRevive', src) end,
    Heal   = function(src) TriggerClientEvent('rsg-medic:client:adminHeal', src) end,
}

function Core.instancePlayers(bucket, src)
    if src then SetPlayerRoutingBucket(src, bucket or 0) end
end

---Discord embed. Same argument order as vorp_core's Core.AddWebhook.
function Core.AddWebhook(title, webhook, description, color, botname, footerlogo, avatar)
    if not webhook or webhook == '' then return end
    local body = {
        username   = botname,
        avatar_url = avatar,
        embeds     = { {
            title       = title,
            description = description,
            color       = tonumber(color) or 16711680,
            footer      = { text = os.date('%Y-%m-%d %H:%M'), icon_url = footerlogo },
        } },
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(body),
        { ['Content-Type'] = 'application/json' })
end

MBridge.Core = Core

-- ------------------------------------------------------------
-- Inventory shim. Method names/arguments follow vorp_inventory,
-- self-first so both INV:addItem(...) and INV.addItem(INV, ...) work.
-- A VORP "item id" is an RSG inventory slot here.
-- ------------------------------------------------------------
local function slotsOf(src)
    local Player = getPlayer(src)
    return Player and Player.PlayerData.items or {}
end

local function cleanInfo(info)
    if type(info) ~= 'table' then return {} end
    -- rsg-inventory stamps decaying items with a numeric quality clock; VORP has
    -- no such thing, and this bridge treats "no metadata" as a plain stack.
    if type(info.quality) == 'number' then
        local copy = {}
        for k, v in pairs(info) do copy[k] = v end
        copy.quality, copy.lastUpdate = nil, nil
        return copy
    end
    return info
end

local function toItem(it)
    if not it then return nil end
    local meta = cleanInfo(it.info)
    local out = {
        id       = it.slot,
        name     = it.name,
        label    = it.label,
        count    = it.amount,
        metadata = meta,
        type     = it.type,
        weight   = it.weight,
        desc     = it.description,
    }
    function out:getId() return self.id end
    function out:getName() return self.name end
    function out:getCount() return self.count end
    function out:getMetadata() return self.metadata end
    function out:getLabel() return self.label end
    return out
end

local function findSlot(src, name, meta)
    local rname = rn(name)
    for slot, it in pairs(slotsOf(src)) do
        if it.name == rname and tablesMatch(cleanInfo(it.info), meta) then return slot, it end
    end
    return nil
end

local function done(cb, value)
    if type(cb) == 'function' then cb(value) end
    return value
end

local INV = {}

-- nan guard: true when a count is a number but NaN / +-inf
local function badCount(n)
    return type(n) == 'number' and (n ~= n or n == math.huge or n == -math.huge)
end

function INV:addItem(src, name, count, metadata, cb)
    if badCount(count) then return done(cb, false) end -- nan guard
    local ok = INVX():AddItem(src, rn(name), count or 1, false, metadata or {}, RES)
    return done(cb, ok and true or false)
end

function INV:subItem(src, name, count, metadata, cb)
    if badCount(count) then return done(cb, false) end -- nan guard
    local ok
    if type(metadata) == 'table' and next(metadata) ~= nil then
        local slot = findSlot(src, name, metadata)
        ok = slot and INVX():RemoveItem(src, rn(name), count or 1, slot, RES) or false
    else
        ok = INVX():RemoveItem(src, rn(name), count or 1, false, RES)
    end
    return done(cb, ok and true or false)
end

function INV:subItemById(src, id, cb, _, amount)
    local it = slotsOf(src)[tonumber(id)]
    if not it or badCount(amount) then return done(cb, false) end -- nan guard
    local ok = INVX():RemoveItem(src, it.name, amount or it.amount or 1, it.slot, RES)
    return done(cb, ok and true or false)
end

function INV:getItemCount(src, cb, name, metadata)
    local n
    if type(metadata) == 'table' and next(metadata) ~= nil then
        n = 0
        for _, it in pairs(slotsOf(src)) do
            if it.name == rn(name) and tablesMatch(cleanInfo(it.info), metadata) then n = n + (it.amount or 0) end
        end
    else
        n = INVX():GetItemCount(src, rn(name)) or 0
    end
    return done(cb, n)
end

function INV:canCarryItem(src, name, count, cb)
    local _, ok = invCall({ 'CanCarry', 'CanAddItem' }, src, rn(name), count or 1)
    return done(cb, ok and true or false)
end

function INV:canCarryWeapons(src, count, cb, weaponName)
    local _, ok = invCall({ 'CanCarry', 'CanAddItem' }, src, rn(weaponName or 'weapon_revolver_cattleman'), count or 1)
    return done(cb, ok and true or false)
end

function INV:getItem(src, name, cb, metadata)
    local _, it = findSlot(src, name, metadata)
    return done(cb, toItem(it))
end

function INV:getItemByName(src, name, cb)
    return INV:getItem(src, name, cb)
end

function INV:getUserInventoryItems(src, cb)
    local out = {}
    for _, it in pairs(slotsOf(src)) do
        if it.type ~= 'weapon' then out[#out + 1] = toItem(it) end
    end
    table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return done(cb, out)
end

function INV:getUserInventoryWeapons(src, cb)
    local out = {}
    for _, it in pairs(slotsOf(src)) do
        if it.type == 'weapon' then
            local info = type(it.info) == 'table' and it.info or {}
            out[#out + 1] = {
                id            = it.slot,
                name          = vn(it.name),
                label         = it.label,
                serial_number = info.serie or info.serial,
                custom_label  = info.custom_label,
                custom_desc   = info.custom_desc,
                components    = info.components or {},
                ammo          = info.ammo or {},
            }
        end
    end
    table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return done(cb, out)
end

-- vorp_inventory: createWeapon(target, name, ammo, components, comps, cb, wepId, serial, label, desc)
function INV:createWeapon(src, name, _ammo, _components, _comps, cb, _wepId, serial, label, desc)
    local info = {
        serie        = serial or ('SH%d%04d'):format(os.time() % 100000, math.random(0, 9999)),
        quality      = 100,
        custom_label = label,
        custom_desc  = desc,
        components   = {},
    }
    local ok = INVX():AddItem(src, rn(name), 1, false, info, RES)
    return done(cb, ok and true or false)
end

function INV:registerUsableItem(name, cb)
    CreateThread(function()
        MBridge.WaitForFramework()
        RSG().Functions.CreateUseableItem(rn(name), function(source, item)
            cb({ source = source, item = toItem(item) or { name = name, metadata = {} } })
        end)
    end)
    return true
end

function INV:closeInventory(src)
    pcall(function() INVX():CloseInventory(src) end)
end

function INV:getItemDB(name)
    local def = RSG().Shared.Items[rn(name)]
    if not def then return nil end
    return {
        item = def.name or name, label = def.label, weight = def.weight,
        limit = def.limit or 0, desc = def.description, type = def.type,
        usable = def.useable and 1 or 0, can_remove = 1,
    }
end

function INV:setItemMetadata(src, id, metadata, _amount, cb)
    local it = slotsOf(src)[tonumber(id)]
    if not it then return done(cb, false) end
    local info = metadata or {}
    if type(it.info) == 'table' and type(it.info.quality) == 'number' then
        info.quality = info.quality or it.info.quality
        info.lastUpdate = info.lastUpdate or it.info.lastUpdate
    end
    local ok = setSlotInfo(src, it, info)
    return done(cb, ok and true or false)
end

-- Weapon parts / labels ride along in the weapon item's info table.
local function editWeaponInfo(src, id, mutate)
    local it = slotsOf(src)[tonumber(id)]
    if not it then return false end
    local info = type(it.info) == 'table' and it.info or {}
    mutate(info)
    return setSlotInfo(src, it, info) and true or false
end

function INV:getWeaponComponents(src, id)
    local it = slotsOf(src)[tonumber(id)]
    local info = it and type(it.info) == 'table' and it.info or {}
    return info.components or {}
end

function INV:addWeaponComponents(src, id, comps)
    return editWeaponInfo(src, id, function(info)
        info.components = info.components or {}
        for cat, comp in pairs(comps or {}) do info.components[cat] = comp end
    end)
end

function INV:subWeaponComponents(src, id, comps)
    return editWeaponInfo(src, id, function(info)
        for cat in pairs(comps or {}) do
            if info.components then info.components[cat] = nil end
        end
    end)
end

function INV:setWeaponCustomLabel(src, id, label)
    return editWeaponInfo(src, id, function(info) info.custom_label = label end)
end

function INV:setWeaponCustomDesc(src, id, desc)
    return editWeaponInfo(src, id, function(info) info.custom_desc = desc end)
end

MBridge.INV = MBridge.SelectINV(INV) -- MULTIinventory proxy when MBridge.IsMultiInv (rsg-inventory emulation otherwise)

---Refill hunger and thirst (rsg keeps them as 0-100 player metadata).
function MBridge.RestoreNeeds(src)
    local p = getPlayer(src)
    if not p then return false end
    p.Functions.SetMetaData('hunger', 100)
    p.Functions.SetMetaData('thirst', 100)
    return true
end

-- ------------------------------------------------------------
-- Character selection
-- ------------------------------------------------------------
function MBridge.OnCharacterSelected(handler)
    AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
        local src = Player and Player.PlayerData and Player.PlayerData.source
        if not src then return end
        handler(src, makeChar(src))
    end)
end

-- Warm the id map for anyone already online (resource restarted mid-session).
CreateThread(function()
    MBridge.WaitForFramework()
    Wait(1000)
    for _, pid in ipairs(GetPlayers()) do
        pcall(function()
            local p = getPlayer(pid)
            if p then MBridge.CharIdOf(p.PlayerData.citizenid) end
        end)
    end
end)

-- ------------------------------------------------------------
-- Character lookups against the rsg-core `players` table
-- ------------------------------------------------------------
MBridge.Chars = {}

-- The join between `players` and the id map is done here in Lua, not in SQL:
-- the two tables can have different collations (an "illegal mix of collations"
-- error on the citizenid join), and this also avoids needing the database's
-- JSON functions.

local function decodeJson(raw)
    if type(raw) == 'table' then return raw end
    local ok, t = pcall(json.decode, raw or '{}')
    return (ok and type(t) == 'table') and t or {}
end

---Give every stored character a numeric id, then load the whole map.
function MBridge.Chars.syncAll()
    ensureMapTable()
    MySQL.query.await(('INSERT IGNORE INTO `%s` (`citizenid`) SELECT `citizenid` FROM `players`'):format(MAP_TABLE))
    local rows = MySQL.query.await(('SELECT `charidentifier`, `citizenid` FROM `%s`'):format(MAP_TABLE)) or {}
    for _, r in ipairs(rows) do
        local id = tonumber(r.charidentifier)
        if id then byCitizen[r.citizenid] = id; byId[id] = r.citizenid end
    end
end

---All characters: { {id, firstname, lastname}, ... }
function MBridge.Chars.list()
    MBridge.Chars.syncAll()
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `citizenid`, `charinfo` FROM `players`') or {}) do
        local id = byCitizen[r.citizenid]
        if id then
            local info = decodeJson(r.charinfo)
            out[#out + 1] = { id = id, firstname = info.firstname or '', lastname = info.lastname or '' }
        end
    end
    return out
end

---One character by numeric id: {id, firstname, lastname} or nil.
function MBridge.Chars.byId(charId)
    local citizenid = MBridge.CitizenOf(charId)
    if not citizenid then return nil end
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ? LIMIT 1', { citizenid })
    if not row then return nil end
    local info = decodeJson(row.charinfo)
    return { id = tonumber(charId), firstname = info.firstname or '', lastname = info.lastname or '' }
end

---Characters whose "first last" equals `lowerFullName` (already lower-cased).
function MBridge.Chars.byFullName(lowerFullName)
    local out = {}
    for _, c in ipairs(MBridge.Chars.list()) do
        if ((c.firstname .. ' ' .. c.lastname):lower()) == lowerFullName then out[#out + 1] = c end
    end
    return out
end

---Credit cash to a character that may be offline. Returns affected rows.
function MBridge.Chars.addCashOffline(charId, amount)
    local citizenid = MBridge.CitizenOf(charId)
    if not citizenid then return 0 end
    local row = MySQL.single.await('SELECT `money` FROM `players` WHERE `citizenid` = ? LIMIT 1', { citizenid })
    if not row then return 0 end
    local money = decodeJson(row.money)
    money.cash = (tonumber(money.cash) or 0) + amount
    return MySQL.update.await('UPDATE `players` SET `money` = ? WHERE `citizenid` = ?',
        { json.encode(money), citizenid }) or 0
end

-- ------------------------------------------------------------
-- Item / weapon catalogue (rsg keeps these in shared Lua, not SQL)
-- ------------------------------------------------------------
MBridge.Items = {}

local catalogueCache, catalogueAt = nil, 0
local function sharedItems()
    local now = GetGameTimer()
    if not catalogueCache or now - catalogueAt > 30000 then
        catalogueCache, catalogueAt = RSG().Shared.Items or {}, now
    end
    return catalogueCache
end

---Rows shaped like the VORP `items` table: item, label, weight, limit, desc, groupId.
function MBridge.Items.catalog()
    local rows = {}
    for name, def in pairs(sharedItems()) do
        if def.type ~= 'weapon' then
            rows[#rows + 1] = {
                item = name, label = def.label or name, weight = def.weight or 0,
                limit = def.limit or 0, desc = def.description or '', groupId = def.category,
            }
        end
    end
    table.sort(rows, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
    return rows
end

---Random sample of `n` catalogue rows.
function MBridge.Items.sample(n)
    local rows = MBridge.Items.catalog()
    local out = {}
    while #out < n and #rows > 0 do
        out[#out + 1] = table.remove(rows, math.random(#rows))
    end
    return out
end

function MBridge.Items.exists(name)
    return sharedItems()[rn(name)] ~= nil
end

---Weapon definitions shaped like vorp_inventory's SHARED_DATA.WEAPONS
---(keyed by upper-case name; Components are not modelled by rsg).
function MBridge.Items.weapons()
    local out = {}
    for name, def in pairs(sharedItems()) do
        if def.type == 'weapon' then
            out[name:upper()] = { Name = def.label or name, Desc = def.description or '',
                                  HashName = name:upper(), Components = {}, Weight = def.weight or 0 }
        end
    end
    return out
end

-- install/items_rsg.lua holds this resource's own items (the RSG counterpart of
-- install/items_vorp.sql). They are registered with rsg-core at start; paste
-- the same entries into rsg-core/shared/items.lua to make them permanent.
-- (rsg/items.lua is still read when an older install kept it there.)
local ITEM_DEFAULTS = {
    weight = 100, type = 'item', unique = false, useable = false,
    shouldClose = true, description = '',
}
local ITEM_FILES = { 'install/items_rsg.lua', 'rsg/items.lua' }

function MBridge.RegisterItems()
    local raw, file
    for _, f in ipairs(ITEM_FILES) do
        raw = LoadResourceFile(RES, f)
        if raw then file = f break end
    end
    if not raw then return 0 end
    local chunk, err = load(raw, '@' .. RES .. '/' .. file, 't', {})
    if not chunk then MBridge.Log('^1%s did not parse: %s^7', file, tostring(err)); return 0 end
    local ok, defs = pcall(chunk)
    if not ok or type(defs) ~= 'table' then MBridge.Log('^1%s did not run^7', file); return 0 end

    local added = 0
    for name, def in pairs(defs) do
        if not RSG().Shared.Items[name] then
            def.name = def.name or name
            for k, v in pairs(ITEM_DEFAULTS) do if def[k] == nil then def[k] = v end end
            def.label = def.label or name
            def.image = def.image or (name .. '.png')
            -- rsg-core export AddItem(name, data) -> true | false, 'item_exists'/'invalid_item_name'
            local okCall, res = pcall(function() return exports['rsg-core']:AddItem(name, def) end)
            if okCall and res ~= false then added = added + 1 end
        end
    end
    catalogueCache = nil
    if added > 0 then MBridge.Log('registered %d item(s) with rsg-core', added) end
    return added
end

CreateThread(function()
    MBridge.WaitForFramework()
    Wait(2500)
    pcall(MBridge.RegisterItems)
end)
