-- ============================================================
-- Offline test of the vorp_inventory face (not loaded by the game:
-- fxmanifest only loads server/vorp/*.lua, not this sub folder).
--
--   lua54 server/vorp/test/vorp_face_test.lua      (run from the MULTIinventory folder)
--
-- MULTIInv is a small in-memory stand-in written to docs/INVENTORY.md's
-- engine API; the weapon / ammo data is the real shared/weapons.lua.
-- ============================================================

local ROOT = (arg and arg[0] or ''):match('^(.*)server[/\\]vorp[/\\]test[/\\]') or './'

-- ------------------------------------------------------------
-- FXServer stand-ins
-- ------------------------------------------------------------
local handlers, clientEvents, printed = {}, {}, {}
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function TriggerEvent(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
function TriggerClientEvent(name, src, ...) clientEvents[#clientEvents + 1] = { name = name, src = src, args = { ... } } end
function GetInvokingResource() return 'test_script' end
function GetCurrentResourceName() return 'MULTIinventory' end
function SetTimeout(_, fn) fn() end
function GetPlayers() return { '1', '2' } end
function GetPlayerName(src) return 'player' .. tostring(src) end
function PerformHttpRequest() end
json = { encode = function() return '{}' end }
local bags = {}
function Player(src)
    bags[src] = bags[src] or {}
    return { state = { set = function(_, k, v) bags[src][k] = v end } }
end

-- joaat (Jenkins one-at-a-time, as the game hashes names)
function joaat(s)
    s = s:lower()
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h
end
GetHashKey = joaat

-- players and their characters (MULTIcore's RSG player object)
local players = {
    [1] = { PlayerData = { source = 1, id = 11, citizenid = 'AAA111', job = { name = 'sheriff', grade = { level = 2 } }, metadata = { vorp = { invCapacity = 20 } } } },
    [2] = { PlayerData = { source = 2, id = 22, citizenid = 'BBB222', job = { name = 'unemployed', grade = { level = 0 } }, metadata = { vorp = { invCapacity = 0 } } } },
}
local Core = { Functions = { GetPlayer = function(src) return players[tonumber(src)] end } }

exports = setmetatable({}, { __index = function(_, res)
    if res == 'rsg-core' then return { GetCoreObject = function() return Core end } end
    return setmetatable({}, { __index = function(_, name)
        return function(_, ...)
            local fn
            TriggerEvent(('__cfx_export_%s_%s'):format(res, name), function(f) fn = f end)
            assert(fn, 'no export ' .. res .. ':' .. name)
            return fn(...)
        end
    end })
end })

-- ------------------------------------------------------------
-- MULTIInv stand-in (docs/INVENTORY.md API)
-- ------------------------------------------------------------
dofile(ROOT .. 'shared/weapons.lua')

local function copy(t) if type(t) ~= 'table' then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
local function eq(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not eq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

MULTIInv = { Items = {}, List = {}, Usables = {}, WeaponData = MULTIInvData.Weapons, Weapon = {}, opened = {} }
local E = MULTIInv
local function def(name, d) d.name = name; d.weight = d.weight or 100; d.limit = d.limit or 0; E.Items[name] = d end
def('bread', { label = 'Bread', type = 'item', usable = true, limit = 10, description = 'Food' })
def('water', { label = 'Water', type = 'item', usable = true })
def('ammo_box_revolver', { label = 'Box', type = 'item' })
for name, w in pairs(MULTIInvData.Weapons) do def(name, { label = name, type = 'weapon', unique = not w.thrown, weight = 1000 }) end
for t, a in pairs(MULTIInvData.Ammo) do if not E.Items[a.item] then def(a.item, { label = t, type = 'ammo', weight = 10 }) end end

local wid = 100
function E.Weapon.New(name, info)
    info = copy(info or {})
    wid = wid + 1
    info.id = tonumber(info.id) or wid
    info.serie = info.serie or ('SER' .. wid)
    info.components = info.components or {}
    return info
end
function E.Weapon.FindById(id)
    for invId, inv in pairs(E.List) do
        for slot, s in pairs(inv.items) do
            if s.info and tonumber(s.info.id) == tonumber(id) then return invId, slot, s end
        end
    end
end
function E.PlayerInv(src)
    local P = players[tonumber(src)]
    return P and ('player:' .. P.PlayerData.citizenid) or nil
end
function E.Create(id, data)
    data = data or {}
    local inv = { id = id, label = data.label or id, slots = tonumber(data.slots) or 30, maxWeight = tonumber(data.maxWeight) or 1e9,
        maxCount = tonumber(data.maxCount), items = {}, itemLimits = data.itemLimits or {}, whitelist = data.whitelist,
        blacklist = data.blacklist, acceptWeapons = data.acceptWeapons, ignoreItemLimits = data.ignoreItemLimits }
    E.List[id] = inv
    return inv
end
function E.Configure(id, data)
    local inv = E.List[id]
    if data.label then inv.label = data.label end
    if data.maxCount ~= nil then inv.maxCount = tonumber(data.maxCount) end
    for _, k in ipairs({ 'itemLimits', 'whitelist', 'blacklist', 'acceptWeapons', 'ignoreItemLimits' }) do
        if data[k] ~= nil then inv[k] = data[k] end
    end
    return inv
end
function E.Exists(id) return E.List[id] end
function E.Get(id)
    if E.List[id] then return E.List[id] end
    if id:find('^player:') or id:find('^custom:') or id:find('^stash:') then return E.Create(id) end
end
local function isSerial(d) local w = MULTIInvData.Weapons[d.name]; return d.type == 'weapon' and not (w and w.thrown) end
local function total(inv) local n = 0 for _, s in pairs(inv.items) do n = n + s.amount end return n end
local function used(inv) local n = 0 for _ in pairs(inv.items) do n = n + 1 end return n end
local function free(inv) for i = 1, inv.slots do if not inv.items[i] then return i end end end
function E.CanAdd(invId, name, amount, info)
    local inv, d = E.Get(invId), E.Items[name]
    if not inv then return false, 'no_inventory' end
    if not d then return false, 'unknown_item' end
    if inv.whitelist and not inv.whitelist[name] then return false, 'not_allowed' end
    if inv.blacklist and inv.blacklist[name] then return false, 'not_allowed' end
    if inv.acceptWeapons == false and d.type == 'weapon' then return false, 'not_allowed' end
    local lim = inv.itemLimits[name] or (inv.id:find('^player:') and d.limit) or 0
    if lim > 0 and E.Count(invId, name) + amount > lim then return false, 'limit' end
    if inv.maxCount and inv.maxCount > 0 and total(inv) + amount > inv.maxCount then return false, 'no_space' end
    if isSerial(d) or d.unique then if inv.slots - used(inv) < amount then return false, 'no_space' end
    else
        for _, s in pairs(inv.items) do if s.name == name and eq(s.info, info or {}) then return true end end
        if inv.slots - used(inv) < 1 then return false, 'no_space' end
    end
    return true
end
function E.AddItem(invId, name, amount, info, slot)
    name = name:lower()
    local ok, err = E.CanAdd(invId, name, amount, info)
    if not ok then return false, err end
    local inv, d = E.Get(invId), E.Items[name]
    if isSerial(d) or d.unique then
        for i = 1, amount do
            local inf = copy(info or {})
            if isSerial(d) then if i > 1 then inf.id, inf.serie = nil, nil end inf = E.Weapon.New(name, inf) end
            local s = free(inv)
            inv.items[s] = { name = name, amount = 1, info = inf, slot = s, label = d.label }
        end
        return true
    end
    for _, s in pairs(inv.items) do
        if s.name == name and eq(s.info, info or {}) then s.amount = s.amount + amount; return true end
    end
    local s = (slot and not inv.items[slot]) and slot or free(inv)
    inv.items[s] = { name = name, amount = amount, info = copy(info or {}), slot = s, label = d.label }
    return true
end
function E.RemoveItem(invId, name, amount, slot)
    local inv = E.Get(invId)
    name = name:lower()
    if slot then
        local s = inv.items[slot]
        if not s or s.name ~= name or s.amount < amount then return false, 'not_enough' end
        s.amount = s.amount - amount
        if s.amount <= 0 then inv.items[slot] = nil end
        return true
    end
    if E.Count(invId, name) < amount then return false, 'not_enough' end
    for sl = 1, inv.slots do
        local s = inv.items[sl]
        if s and s.name == name and amount > 0 then
            local take = math.min(amount, s.amount)
            s.amount = s.amount - take; amount = amount - take
            if s.amount <= 0 then inv.items[sl] = nil end
        end
    end
    return true
end
function E.Count(invId, name)
    local n = 0
    for _, s in pairs(E.Get(invId).items) do if s.name == name then n = n + s.amount end end
    return n
end
function E.ReplaceInfo(invId, slot, info)
    local s = E.Get(invId).items[slot]
    if not s then return false end
    s.info = copy(info)
    return true
end
function E.SetInfo(invId, slot, info) local s = E.Get(invId).items[slot]; for k, v in pairs(info) do s.info[k] = v end return true end
function E.RegisterUsable(name, fn) E.Usables[name] = fn return true end
function E.UnregisterUsable(name) E.Usables[name] = nil end
function E.Use(src, slot)
    local invId = E.PlayerInv(src)
    local s = E.Get(invId).items[slot]
    if s and E.Usables[s.name] then E.Usables[s.name](src, s, invId) end
end
function E.Open(src, inv, opts) E.opened[src] = { inv = inv or 'own', opts = opts } return true end
function E.Close(src) E.opened[src] = nil end
function E.Delete(id) E.List[id] = nil return true end

Config = { Vorp = {} }

-- ------------------------------------------------------------
-- load the face
-- ------------------------------------------------------------
for _, f in ipairs({ '00_face.lua', '05_ammo.lua', '10_items.lua', '20_weapons.lua', '30_custom.lua', '40_legacy.lua', '50_state.lua' }) do
    dofile(ROOT .. 'server/vorp/' .. f)
end

local VI = exports.vorp_inventory
local pass, fail = 0, 0
local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print('FAIL: ' .. msg) end
end

-- ---------------- items ----------------
check(VI:addItem(1, 'bread', 3) == true, 'addItem returns true')
local cbVal
VI:addItem(1, 'bread', 2, nil, function(ok) cbVal = ok end)
check(cbVal == true, 'addItem callback')
check(VI:getItemCount(1, nil, 'bread') == 5, 'getItemCount (cb nil, item)')
check(VI:getItemCount(1, 'bread') == 5, 'getItemCount (item second)')
local counted
VI:getItemCount(1, function(n) counted = n end, 'bread')
check(counted == 5, 'getItemCount callback')
check(VI:addItem(1, 'bread', 6) == false, 'per-item limit (10)')
check(VI:addItem(1, 'nope', 1) == false, 'unknown item')
check(VI:addItem(1, 'bread', 0/0) == false, 'nan amount')
check(VI:addItem(1, 'water', 1, { brand = 'x' }) == true, 'add with metadata')
check(VI:getItemCount(1, nil, 'water', { brand = 'x' }) == 1, 'count by metadata')
check(VI:getItemCount(1, nil, 'water', { brand = 'y' }) == 0, 'count by other metadata')

local it = VI:getItem(1, 'bread')
check(it and it.name == 'bread' and it.count == 5 and it.amount == 5 and it.label == 'Bread', 'getItem shape')
check(it and type(it.id) == 'number' and it.mainid == it.id and it.type == 'item_standard' and it.limit == 10, 'getItem id / type / limit')
check(it and it.weight == 0.1 and it.desc == 'Food' and it.canUse == true and it.percentage == 100, 'getItem weight kg / desc / canUse')
local again = VI:getItem(1, 'bread')
check(again.id == it.id, 'id is stable for a stack')
check(VI:getItemById(1, it.id).name == 'bread', 'getItemById')
check(VI:getItemByMainId(1, it.id).count == 5, 'getItemByMainId')

local list = VI:getUserInventoryItems(1)
check(#list == 2, 'getUserInventoryItems lists 2 stacks')

-- invCapacity 20 (character 1): bread 5 + water 1 = 6
check(VI:canCarryItems(1, 14) == true, 'canCarryItems under capacity')
check(VI:canCarryItems(1, 15) == false, 'canCarryItems over capacity')
check(VI:canCarryItem(1, 'water', 15) == false, 'canCarryItem respects invCapacity')
check(VI:canCarryItem(1, 'water', 14) == true, 'canCarryItem ok')
players[1].PlayerData.metadata.vorp.invCapacity = 100   -- updateInvCapacity
check(VI:canCarryItem(1, 'water', 50) == true, 'capacity change is read live')
players[1].PlayerData.metadata.vorp.invCapacity = 20

-- subItem / subItemById
check(VI:subItem(1, 'bread', 2) == true, 'subItem')
check(VI:getItemCount(1, nil, 'bread') == 3, 'after subItem')
check(VI:subItem(1, 'bread', 9) == false, 'subItem more than held')
check(VI:subItem(1, 'water', 1, { brand = 'y' }) == false, 'subItem wrong metadata')
local w = VI:getItem(1, 'water', nil, { brand = 'x' })
check(w and w.metadata.brand == 'x', 'getItem with metadata')
check(VI:subItemById(1, w.id) == true, 'subItemById whole stack')
check(VI:getItemCount(1, nil, 'water') == 0, 'water gone')

-- setItemMetadata: split 1 off a stack of 3
local b = VI:getItem(1, 'bread')
check(VI:setItemMetadata(1, b.id, { cooked = true }, 1) == true, 'setItemMetadata split')
check(VI:getItemCount(1, nil, 'bread', { cooked = true }) == 1, 'split stack has metadata')
check(VI:getItemCount(1, nil, 'bread') == 3, 'total unchanged')
check(VI:getItemContainingMetadata(1, 'bread', { cooked = true }).count == 1, 'getItemContainingMetadata')
check(VI:getItemMatchingMetadata(1, 'bread', {}).count == 2, 'getItemMatchingMetadata (none)')

-- events
local created
AddEventHandler('vorp_inventory:Server:OnItemCreated', function(data, src) created = { data, src } end)
VI:addItem(1, 'water', 1)
check(created and created[1].name == 'water' and created[1].count == 1 and created[2] == 1, 'OnItemCreated')
created = nil
VI:addItem(1, 'water', 1, nil, nil, true)
check(created == nil, 'event = true suppresses OnItemCreated')

-- getItemDB
local db = VI:getItemDB('bread')
check(db and db.item == 'bread' and db.label == 'Bread' and db.limit == 10 and db.usable == 1 and db.can_remove == 1, 'getItemDB row')

-- usable
local used
check(VI:registerUsableItem('bread', function(data) used = data end, 'test') == true, 'registerUsableItem')
local useEvt
AddEventHandler('vorp_inventory:Server:OnItemUse', function(d) useEvt = d end)
local slot
for s, st in pairs(E.Get('player:AAA111').items) do if st.name == 'bread' then slot = s break end end
E.Use(1, slot)
check(used and used.source == 1 and used.item and used.item.name == 'bread' and used.item.metadata and used.item.id, 'usable data shape (source, item)')
check(used and used.name == 'bread' and used.count, 'usable data flat fields')
check(useEvt and useEvt.item.name == 'bread', 'OnItemUse fired')
VI:unRegisterUsableItem('bread')
used = nil
E.Use(1, slot)
check(used == nil, 'unRegisterUsableItem')

-- ---------------- weapons ----------------
check(VI:createWeapon(1, 'WEAPON_REVOLVER_CATTLEMAN', { AMMO_REVOLVER = 6 }, {}, { BARREL = 'comp_a' }, nil, nil, 'MYSERIAL', 'Old Betsy', 'A gun') == true, 'createWeapon')
local ws = VI:getUserInventoryWeapons(1)
check(#ws == 1, 'one weapon')
local gun = ws[1]
check(gun.name == 'WEAPON_REVOLVER_CATTLEMAN' and gun.serial_number == 'MYSERIAL' and gun.custom_label == 'Old Betsy' and gun.custom_desc == 'A gun', 'weapon shape')
check(gun.ammo.AMMO_REVOLVER == 6 and gun.comps.BARREL == 'comp_a' and type(gun.id) == 'number', 'weapon ammo / comps / id')
check(VI:getUserWeapon(1, nil, gun.id).id == gun.id, 'getUserWeapon')
check(VI:getWeaponBullets(1, gun.id) == 6, 'getWeaponBullets')
check(VI:canCarryWeapons(1, 1, nil, 'WEAPON_REVOLVER_SCHOFIELD') == true, 'canCarryWeapons')
check(VI:setWeaponCustomLabel(gun.id, 'New name') == true, 'setWeaponCustomLabel (short form)')
check(VI:setWeaponCustomDesc(1, gun.id, 'Desc 2') == true, 'setWeaponCustomDesc (source form)')
check(VI:setWeaponSerialNumber(gun.id, 'SN2') == true, 'setWeaponSerialNumber')
gun = VI:getUserWeapon(1, nil, gun.id)
check(gun.custom_label == 'New name' and gun.custom_desc == 'Desc 2' and gun.serial_number == 'SN2', 'edits stuck')
check(VI:addWeaponComponents(1, gun.id, { comp_b = 'GRIP' }) == true, 'addWeaponComponents')
check(VI:getWeaponComponents(1, gun.id).GRIP == 'comp_b', 'getWeaponComponents')
check(VI:subWeaponComponent(1, gun.id, 'comp_b', 'GRIP') == true and VI:getWeaponComponents(1, gun.id).GRIP == nil, 'subWeaponComponent')

-- ammo
check(VI:addBullets(1, 'AMMO_REVOLVER', 20) == true, 'addBullets AMMO_REVOLVER')
check(VI:addBullets(1, 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', 5) == true, 'addBullets explosive pistol')
check(VI:addBullets(1, 'AMMO_ARROW_FIRE', 3) == true, 'addBullets fire arrows')
check(VI:addBullets(1, 'AMMO_ARROW_SMALL_GAME', 4) == true, 'addBullets small arrows')
check(VI:addBullets(1, 'AMMO_TOMAHAWK', 2) == true, 'addBullets thrown (tomahawk)')
check(VI:addBullets(1, 'ammo_rifle_split_point', 7) == true, 'addBullets by item name')
check(VI:addBullets(1, 'AMMO_NOT_REAL', 7) == false, 'addBullets unknown type')
local ammo = VI:getUserAmmo(1)
check(ammo.AMMO_REVOLVER == 20 and ammo.AMMO_PISTOL_EXPRESS_EXPLOSIVE == 5 and ammo.AMMO_ARROW_FIRE == 3, 'getUserAmmo rounds')
check(ammo.AMMO_ARROW_SMALL_GAME == 4 and ammo.AMMO_TOMAHAWK == 2 and ammo.AMMO_RIFLE_SPLIT_POINT == 7, 'getUserAmmo arrows / thrown / by item')
check(VI:getItemCount(1, nil, 'weapon_thrown_tomahawk') == 2, 'thrown weapons are their item count')
check(VI:canCarryItems(1, 13) == true, 'ammo and weapons do not count for invCapacity')
-- subBullets: 6 loaded + 20 in the satchel
check(VI:subBullets(gun.id, 'AMMO_REVOLVER', 8) == true, 'subBullets (doc form)')
check(VI:getWeaponBullets(1, gun.id) == 0 and VI:getUserAmmo(1).AMMO_REVOLVER == 18, 'subBullets takes loaded first, then satchel')
check(VI:subBullets(1, gun.id, 'AMMO_REVOLVER', 100) == false, 'subBullets (source form) too many')
-- every ammo type the engine knows has an item
local missing = {}
for t in pairs(MULTIInvData.Ammo) do if not MULTIVorp.AmmoItem(t) then missing[#missing + 1] = t end end
check(#missing == 0, 'every engine ammo type maps: ' .. table.concat(missing, ','))
check(select(2, MULTIVorp.AmmoItem('AMMO_DYNAMITE')) == true and MULTIVorp.AmmoItem('AMMO_DYNAMITE') == 'weapon_thrown_dynamite', 'dynamite is thrown')
check(MULTIVorp.AmmoItem('AMMO_22_TRANQUILIZER') == 'ammo_22_tranquilizer', 'varmint tranquilizer')
check(MULTIVorp.AmmoType(joaat('AMMO_REVOLVER')) == 'AMMO_REVOLVER', 'ammo by hash')
VI:removeAllUserAmmo(1)
ammo = VI:getUserAmmo(1)
check(ammo.AMMO_REVOLVER == nil and ammo.AMMO_ARROW_FIRE == nil and ammo.AMMO_TOMAHAWK == 2, 'removeAllUserAmmo keeps thrown weapons')

-- give / sub / delete
check(VI:giveWeapon(2, gun.id, 1) == true, 'giveWeapon to source 2')
check(#VI:getUserInventoryWeapons(1) == 1 and #VI:getUserInventoryWeapons(2) == 1, 'weapon moved (tomahawk stays with 1)')
check(VI:getUserWeapon(2, nil, gun.id).serial_number == 'SN2', 'weapon kept its info')
check(VI:subWeapon(2, gun.id) == true and #VI:getUserInventoryWeapons(2) == 0, 'subWeapon')
check(VI:addItem(2, 'WEAPON_PISTOL_MAUSER', 1) == true and #VI:getUserInventoryWeapons(2) == 1, 'addItem with a weapon makes a weapon')
local p = VI:getUserInventoryWeapons(2)[1]
check(VI:deleteWeapon(2, p.id) == true, 'deleteWeapon')

-- ---------------- custom inventories ----------------
check(VI:registerInventory({ id = 'barn', name = 'Barn', limit = 10, acceptWeapons = false, shared = true }) == true, 'registerInventory')
check(VI:isCustomInventoryRegistered('barn') == true, 'isCustomInventoryRegistered')
check(VI:addItemsToCustomInventory('barn', { { name = 'bread', amount = 4 } }) == true, 'addItemsToCustomInventory')
check(VI:getCustomInventoryItemCount('barn', 'bread') == 4, 'getCustomInventoryItemCount')
local ci = VI:getCustomInventoryItems('barn')
check(#ci == 1 and ci[1].name == 'bread' and ci[1].amount == 4, 'getCustomInventoryItems')
check(VI:addItemsToCustomInventory('barn', { bread = 7 }) == false, 'custom limit (10 total)')
check(VI:addWeaponsToCustomInventory('barn', { { name = 'WEAPON_REVOLVER_NAVY' } }) == false, 'acceptWeapons = false')
check(VI:updateCustomInventorySlots('barn', 30) == true and VI:getCustomInventorySlots('barn') == 30, 'updateCustomInventorySlots')
check(VI:addItemsToCustomInventory('barn', { bread = 7 }) == true, 'more room after slots update')
check(VI:removeItemFromCustomInventory('barn', 'bread', 5) == true and VI:getCustomInventoryItemCount('barn', 'bread') == 6, 'removeItemFromCustomInventory')
VI:BlackListCustomAny('barn', 'water')
check(VI:addItemsToCustomInventory('barn', { water = 1 }) == true, 'black list off until UseBlackList')
VI:registerInventory({ id = 'barn', name = 'Barn', limit = 30, shared = true, UseBlackList = true })
check(VI:addItemsToCustomInventory('barn', { water = 1 }) == false, 'black list with UseBlackList')

VI:registerInventory({ id = 'locker', name = 'Locker', limit = 50, shared = false, whitelistItems = true, UsePermissions = true })
VI:setCustomInventoryItemLimit('locker', 'water', 2)
check(VI:addItemsToCustomInventory('locker', { water = 2 }, 11) == true, 'white listed item (per char)')
check(VI:addItemsToCustomInventory('locker', { water = 1 }, 11) == false, 'white list limit')
check(VI:addItemsToCustomInventory('locker', { bread = 1 }, 11) == false, 'not white listed')
check(E.List['custom:locker:11'] ~= nil, 'per-character id')
VI:AddPermissionMoveToCustom('locker', 'sheriff', 3)
local inv = E.List['custom:locker:11']
check(inv.canPut(1, 'water', 0) == false, 'job grade too low')
VI:AddPermissionMoveToCustom('locker', 'sheriff', 2)
check(inv.canPut(1, 'water', 0) == true, 'job grade ok')
check(inv.canPut(2, 'water', 0) == false, 'other job refused')
VI:AddCharIdPermissionMoveToCustom('locker', 22, true)
check(inv.canPut(2, 'water', 0) == true, 'char id permission')

check(VI:openInventory(1, 'locker') == true and E.opened[1].inv == 'custom:locker:11', 'openInventory custom (per char)')
check(VI:openInventory(1) == true and E.opened[1].inv == 'own', 'openInventory own satchel')
VI:closeInventory(1)
check(E.opened[1] == nil, 'closeInventory')
check(VI:openPlayerInventory({ source = 2, target = 1, title = 'Search' }) == true and E.opened[2].inv == 'player:AAA111', 'openPlayerInventory')
check(VI:deleteCustomInventory('barn') == true and VI:isCustomInventoryRegistered('barn') == false, 'deleteCustomInventory')

-- ---------------- old API ----------------
local Api = VI:vorp_inventoryApi()
check(Api.getItemCount(1, 'bread') == 3, 'vorp_inventoryApi getItemCount')
local evc
TriggerEvent('vorpCore:getItemCount', 1, function(n) evc = n end, 'bread')
check(evc == 3, 'vorpCore:getItemCount event')
TriggerEvent('vorpCore:addItem', 1, 'bread', 1)
check(VI:getItemCount(1, nil, 'bread') == 4, 'vorpCore:addItem event')

print(('vorp face test: %d passed, %d failed'):format(pass, fail))
if fail > 0 then os.exit(1) end
