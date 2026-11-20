-- ============================================================
-- MULTIinventory :: server/multi/faces.lua
--
-- MULTIinventory answers under three more names (fxmanifest `provide`):
--   rsg-inventory      exports['rsg-inventory']:X       -> server/rsg/rsg_api.lua (Rsg_X)
--   vorp_inventory     exports.vorp_inventory:x         -> server/compat/vorp_api.lua (Compat_x)
--   redemrp_inventory  TriggerEvent('redemrp_inventory:getData', cb) + exports['redemrp_inventory']:X
-- The runtime looks an export up through the event '__cfx_export_<resource>_<name>', so a
-- handler for that event is all an alias takes (the same way MULTIcore answers as rsg-core).
-- The VORP and RedEM:RP faces were written from their public API documentation; no code of
-- those inventories is used.
-- ============================================================

local M = MultiInv
local API = M.API

local function alias(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB) setCB(fn) end)
end
M.alias = alias

-- ------------------------------------------------------------
-- rsg-inventory
-- ------------------------------------------------------------
for _, name in ipairs(RsgInv.NAMES) do
    alias('rsg-inventory', name, function(...) return RsgInv.run(name, GetInvokingResource(), ...) end)
end

-- events rsg scripts send (the rest live in server/rsg/rsg_api.lua)
RegisterNetEvent('rsg-inventory:server:closeInventory', function(id)
    local src = source
    if type(id) == 'string' and State.secondaryOf(src) and State.secondaryOf(src) ~= id then return end
    if State.isOpen(src) then State.close(src, false) end
end)

-- rsg's search rule: dead players by anyone, cuffed ones by the law (callers check more themselves)
RegisterNetEvent('rsg-inventory:server:openPlayerInventory', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    local P, T = RsgInv.getPlayer(src), targetId and RsgInv.getPlayer(targetId)
    if not P or not T or targetId == src then return end
    local a, b = M.PlayerCoords(src), M.PlayerCoords(targetId)
    if not a or not b or #(a - b) > 3.0 then return end
    local meta = T.PlayerData.metadata or {}
    local job = P.PlayerData.job and P.PlayerData.job.name
    local law = job == 'police' or job == 'marshal' or job == 'sheriff' or IsPlayerAceAllowed(src, 'command')
    if not meta.isdead and not (meta.ishandcuffed and law) then return end
    API.OpenPlayer(src, targetId)
end)

-- open requests from the rsg client events (rsg-inventory:client:openInventory fallbacks)
RegisterNetEvent('MULTIinventory:server:openSelf', function()
    local src = source
    if State.get(src) then State.open(src, nil) end
end)

-- ------------------------------------------------------------
-- vorp_inventory
-- ------------------------------------------------------------
local V = VorpCompat.server

local function vorp(name, fn)
    alias('vorp_inventory', name, function(...) return fn(...) end)
end

for _, name in ipairs(VorpCompat.NAMES) do
    alias('vorp_inventory', name, function(...) return VorpCompat.call(name, GetInvokingResource(), ...) end)
end

local function done(cb, value)
    if VorpCompat.callable(cb) then pcall(cb, value) end
    return value
end

local function playerGrid(src)
    local id = M.PlayerInv(src)
    return id and M.container(id) or nil
end

---first stack of the item whose metadata holds every key of `meta` (containing) or equals it (matching)
local function findByMeta(src, name, meta, exact)
    local c = playerGrid(src)
    if not c or type(name) ~= 'string' then return nil end
    local slots = {}
    for slot in pairs(c.stacks) do slots[#slots + 1] = slot end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        local e = c.stacks[slot]
        if e.kind ~= 'weapon' and e.item == name then
            local m = e.metadata or {}
            local ok = true
            if exact then
                ok = Meta.equal(m, meta or {})
            else
                for k, v in pairs(type(meta) == 'table' and meta or {}) do
                    if not Meta.equal({ v = m[k] }, { v = v }) then ok = false break end
                end
            end
            if ok then return VorpCompat.vItem(Sync.itemTable(e, c)) end
        end
    end
    return nil
end

vorp('subItemID', function(src, id, cb, allowEvent, amount) return V.subItemById(src, id, cb, allowEvent, amount) end)
vorp('getItemByMainId', function(src, id, cb) return V.getItemById(src, id, cb) end)
vorp('getUserInventory', function(src, cb) return V.getUserInventoryItems(src, cb) end)
vorp('getUserWeapons', function(src, cb) return V.getUserInventoryWeapons(src, cb) end)
vorp('getWeapon', function(src, cb, weaponId) return V.getUserWeapon(src, cb, weaponId) end)
vorp('setWeaponSerial', function(src, weaponId, serial, cb) return V.setWeaponSerialNumber(src, weaponId, serial, cb) end)
vorp('removeCustomInventory', function(id) return V.removeInventory(id) end)
vorp('getItemContainingMetadata', function(src, name, meta, cb)
    if VorpCompat.callable(meta) and cb == nil then meta, cb = nil, meta end
    InvDB.awaitReady()
    return done(cb, findByMeta(src, name, meta, false))
end)
vorp('getItemMatchingMetadata', function(src, name, meta, cb)
    if VorpCompat.callable(meta) and cb == nil then meta, cb = nil, meta end
    InvDB.awaitReady()
    return done(cb, findByMeta(src, name, meta, true))
end)

-- the object older VORP scripts keep (exports.vorp_inventory:vorp_inventoryApi()); methods take no callbacks
local VApi = {
    addItem = function(src, item, amount, metadata) return V.addItem(src, item, amount, metadata) end,
    subItem = function(src, item, amount, metadata) return V.subItem(src, item, amount, metadata) end,
    subItemID = function(src, id) return V.subItemById(src, id) end,
    getItemCount = function(src, item, metadata) return V.getItemCount(src, nil, item, metadata) end,
    getItem = function(src, item, metadata) return V.getItem(src, item, nil, metadata) end,
    getItemByMainId = function(src, id) return V.getItemById(src, id) end,
    getUserInventory = function(src) return V.getUserInventoryItems(src) end,
    canCarryItems = function(src, amount) return V.canCarryItems(src, amount) end,
    canCarryItem = function(src, item, amount) return V.canCarryItem(src, item, amount) end,
    RegisterUsableItem = function(item, cb) return V.registerUsableItem(item, cb, GetInvokingResource()) end,
    getDBItem = function(_, item) return V.getItemDB(item) end,
    setItemMetadata = function(src, id, metadata) return V.setItemMetadata(src, id, metadata) end,
    createWeapon = function(src, name, ammo, components) return V.createWeapon(src, name, ammo, components) end,
    giveWeapon = function(src, weaponId, target) return V.giveWeapon(src, weaponId, target) end,
    subWeapon = function(src, weaponId) return V.subWeapon(src, weaponId) end,
    getWeaponBullets = function(src, weaponId) return V.getWeaponBullets(src, weaponId) end,
    getWeaponComponents = function(src, weaponId) return V.getWeaponComponents(src, weaponId) end,
    getUserWeapons = function(src) return V.getUserInventoryWeapons(src) end,
    getUserWeapon = function(src, weaponId) return V.getUserWeapon(src, nil, weaponId) end,
    canCarryWeapons = function(src, amount, name) return V.canCarryWeapons(src, amount, nil, name) end,
    addBullets = function(src, bulletType, amount) return V.addBullets(src, bulletType, amount) end,
    subBullets = function(src, weaponId, bulletType, amount) return V.subBullets(weaponId, bulletType, amount) end,
    getUserAmmo = function(src) return V.getUserAmmo(src) end,
    CloseInv = function(src) return V.closeInventory(src) end,
    OpenInv = function(src) return V.openInventory(src) end,
    registerInventory = function(id, name, limit, acceptWeapons, shared, ignoreItemStackLimit)
        if type(id) == 'table' then return V.registerInventory(id) end
        return V.registerInventory({ id = id, name = name, limit = limit, acceptWeapons = acceptWeapons,
                                     shared = shared, ignoreItemStackLimit = ignoreItemStackLimit })
    end,
    removeInventory = function(id) return V.removeInventory(id) end,
    openInventory = function(src, id) return V.openInventory(src, id) end,
    closeInventory = function(src) return V.closeInventory(src) end,
}
vorp('vorp_inventoryApi', function() return VApi end)

-- the oldest VORP API: server-local events with a callback
local function cbv(cb, value) return done(cb, value) end
local legacy = {
    ['vorpCore:addItem']          = function(src, item, amount, metadata, cb) return cbv(cb, V.addItem(src, item, amount, metadata)) end,
    ['vorpCore:subItem']          = function(src, item, amount, metadata, cb) return cbv(cb, V.subItem(src, item, amount, metadata)) end,
    ['vorpCore:subItemID']        = function(src, id, cb) return cbv(cb, V.subItemById(src, id)) end,
    ['vorpCore:getItemCount']     = function(src, cb, item, metadata) return cbv(cb, V.getItemCount(src, nil, item, metadata)) end,
    ['vorpCore:getItem']          = function(src, item, cb, metadata) return cbv(cb, V.getItem(src, item, nil, metadata)) end,
    ['vorpCore:getUserInventory'] = function(src, cb) return cbv(cb, V.getUserInventoryItems(src)) end,
    ['vorpCore:canCarryItems']    = function(src, amount, cb) return cbv(cb, V.canCarryItems(src, amount)) end,
    ['vorpCore:canCarryItem']     = function(src, item, amount, cb) return cbv(cb, V.canCarryItem(src, item, amount)) end,
    ['vorpCore:getItemDB']        = function(item, cb) return cbv(cb, V.getItemDB(item)) end,
    ['vorpCore:createWeapon']     = function(src, name, ammo, components, cb) return cbv(cb, V.createWeapon(src, name, ammo, components)) end,
    ['vorpCore:giveWeapon']       = function(src, weaponId, target, cb) return cbv(cb, V.giveWeapon(src, weaponId, target)) end,
    ['vorpCore:subWeapon']        = function(src, weaponId, cb) return cbv(cb, V.subWeapon(src, weaponId)) end,
    ['vorpCore:getUserWeapons']   = function(src, cb) return cbv(cb, V.getUserInventoryWeapons(src)) end,
    ['vorpCore:getUserWeapon']    = function(src, cb, weaponId) return cbv(cb, V.getUserWeapon(src, nil, weaponId)) end,
    ['vorpCore:canCarryWeapons']  = function(src, amount, cb, name) return cbv(cb, V.canCarryWeapons(src, amount, nil, name)) end,
    ['vorpCore:getWeaponBullets'] = function(src, cb, weaponId) return cbv(cb, V.getWeaponBullets(src, weaponId)) end,
    ['vorpCore:getWeaponComponents'] = function(src, cb, weaponId) return cbv(cb, V.getWeaponComponents(src, weaponId)) end,
    ['vorpCore:addBullets']       = function(src, bulletType, amount, cb) return cbv(cb, V.addBullets(src, bulletType, amount)) end,
    ['vorpCore:subBullets']       = function(_src, weaponId, bulletType, amount, cb) return cbv(cb, V.subBullets(weaponId, bulletType, amount)) end,
    ['vorpCore:getUserAmmo']      = function(src, cb) return cbv(cb, V.getUserAmmo(src)) end,
    ['vorpCore:removeAllUserAmmo'] = function(src) return V.removeAllUserAmmo(src) end,
    ['vorpCore:openInventory']    = function(src, id) return V.openInventory(src, id) end,
    ['vorpCore:closeInventory']   = function(src) return V.closeInventory(src) end,
}
for name, fn in pairs(legacy) do
    -- server side only: a client never reaches these
    AddEventHandler(name, function(...)
        local args = table.pack(...)
        CreateThread(function()
            local ok, err = pcall(fn, table.unpack(args, 1, args.n))
            if not ok then print(('^3[MULTIinventory] %s failed: %s^7'):format(name, tostring(err))) end
        end)
    end)
end
AddEventHandler('vorpCore:registerUsableItem', function(item, cb) V.registerUsableItem(item, cb, GetInvokingResource()) end)

-- ------------------------------------------------------------
-- redemrp_inventory
-- RedEM:RP scripts get the API with TriggerEvent('redemrp_inventory:getData', function(Inv) ... end)
-- and work with Inv.getItem(src, name, meta).AddItem / RemoveItem / ItemAmount. Differences from
-- the original, all on the safe side: ItemAmount counts every stack of the item, AddItem only drops
-- what does not fit on the ground when makepickup is true, an unknown item gives ItemAmount 0.
-- Item names are matched without case ('WEAPON_REVOLVER_CATTLEMAN' = weapon_revolver_cattleman).
-- ------------------------------------------------------------

---a MULTIcore item as RedEM:RP describes it (weight in kg)
local function itemInfo(def)
    if not def then return nil end
    local weapon = def.type == 'weapon'
    return {
        label = def.label,
        description = def.description or '',
        weight = (tonumber(def.weight) or 0) / 1000,
        canBeDropped = def.delete ~= false,
        canBeUsed = def.useable == true or weapon,
        limit = (tonumber(def.limit) or 0) > 0 and tonumber(def.limit) or (def.unique and 1 or 1000),
        imgsrc = def.image and ('items/' .. def.image) or nil,
        type = weapon and 'item_weapon' or 'item_standard',
        weaponHash = weapon and joaat(def.name:upper()) or nil,
    }
end

local function emptyMeta(meta) return type(meta) ~= 'table' or next(meta) == nil end

local R = {}

---ItemData for one item of one player (never nil)
function R.getItem(src, name, meta)
    InvDB.awaitReady()
    src = tonumber(src)
    name = type(name) == 'string' and name:lower() or ''
    local def = M.def(name)
    local invId = M.PlayerInv(src)
    local match = (not emptyMeta(meta)) and meta or nil
    local stacks = invId and API.FindItems(invId, name, match) or {}
    local total = 0
    for _, st in ipairs(stacks) do total = total + (tonumber(st.amount) or 0) end

    local data = {
        ItemAmount = total,
        ItemInfo = itemInfo(def),
        ItemMeta = stacks[1] and stacks[1].info or (type(meta) == 'table' and meta or {}),
    }

    ---Adds amount (a weapon: the weapon, with `amount` rounds). makepickup = true drops what does not fit.
    function data.AddItem(amount, makepickup)
        amount = math.floor(tonumber(amount) or 1)
        if not def or not invId or amount < 1 then return false end
        local count, info = amount, match and Util.deepcopy(match) or nil
        if def.type == 'weapon' then
            info = info or {}
            info.ammo = { [tostring(def.ammotype or '')] = amount }
            if not def.ammotype then info.ammo = nil end
            count = 1
        end
        local ok, err = API.AddItem(invId, name, count, info, nil, 'redem')
        if ok then
            API.ItemBox(src, name, count, 'add')
            return true
        end
        if makepickup == true and (err == 'too_heavy' or err == 'no_space' or err == 'limit') then
            return RsgInv.API.ForceDropItem(src, name, count, info, 'redem') and true or false
        end
        return false
    end

    function data.RemoveItem(amount)
        amount = math.floor(tonumber(amount) or 1)
        if not def or not invId or amount < 1 or total < amount then return false end
        local ok = API.RemoveItem(invId, name, amount, nil, match, 'redem')
        if ok then API.ItemBox(src, name, amount, 'remove') end
        return ok and true or false
    end

    if stacks[1] then
        function data.ChangeMeta(newMeta)
            if type(newMeta) ~= 'table' then return false end
            return API.ReplaceInfo(invId, stacks[1].slot, newMeta) and true or false
        end
        function data.getAllItemOfName(n)
            local list = {}
            for _, st in ipairs(API.FindItems(invId, (n or name):lower())) do
                list[#list + 1] = { name = st.name, amount = st.amount, meta = st.info or {} }
            end
            return list
        end
    end
    return data
end

function R.getItemData(name)
    return itemInfo(type(name) == 'string' and M.def(name:lower()) or nil)
end

---the player's whole satchel as RedEM:RP lists it
function R.getPlayerInventory(src)
    InvDB.awaitReady()
    local out = {}
    local inv = API.Exists(M.PlayerInv(src) or '')
    for _, st in pairs(inv and inv.items or {}) do
        local info = itemInfo(M.def(st.name)) or {}
        out[#out + 1] = {
            name = st.name, amount = st.amount, meta = st.info or {},
            label = info.label, type = info.type, weaponHash = info.weaponHash,
            weight = info.weight, description = info.description, imgsrc = info.imgsrc,
        }
    end
    return out
end

function R.removePlayerInventory(src)
    InvDB.awaitReady()
    local id = M.PlayerInv(src)
    if id then Inv.clear(id, { occupants = true }, { reason = 'api', note = 'redem' }) end
end

M.Redem = R

AddEventHandler('redemrp_inventory:getData', function(cb) if cb then cb(R) end end)

alias('redemrp_inventory', 'GetItemsList', function()
    local out = {}
    for name, def in pairs(M.items()) do
        local info = itemInfo(def)
        out[name] = info
        if info.type == 'item_weapon' then out[name:upper()] = info end
    end
    return out
end)

alias('redemrp_inventory', 'GetStashWeight', function(id)
    local inv = type(id) == 'string' and API.Exists('stash:redem_' .. id)
    return inv and (inv.weight or 0) / 1000 or 0
end)

-- stashes: RedEM:RP opens them with the client event redemrp_inventory:OpenStash(id, kg);
-- the client face asks here
local CID = '%u%u%u%d%d%d%d%d'
local lastOpen = {}

RegisterNetEvent('MULTIinventory:redem:openStash', function(id, kg)
    local src = source
    local now = GetGameTimer()
    if lastOpen[src] and now - lastOpen[src] < 500 then return end
    lastOpen[src] = now
    if type(id) ~= 'string' or #id > 64 or not id:match('^[%w_%-%.]+$') then return end
    local P = RsgInv.getPlayer(src)
    if not P then return end
    -- a stash named after a character belongs to that character only
    local cid = id:match(CID)
    if cid and cid ~= P.PlayerData.citizenid then return end
    -- a job stash belongs to that job
    local job = id:match('^bossstash_(.+)$')
    if job and job ~= (P.PlayerData.job and P.PlayerData.job.name) then return end
    local kgN = math.max(1, math.min(tonumber(kg) or 60.0, 10000))
    local spec = { label = id, slots = Config.Redem and Config.Redem.StashSlots or 50, maxWeight = math.floor(kgN * 1000) }
    M.Open(src, 'stash:redem_' .. id, spec)
end)
AddEventHandler('playerDropped', function() lastOpen[source] = nil end)

-- RedEM:RP's client check RedEM.TriggerCallback('redemrp_inventory:server:HasItem', cb, name)
CreateThread(function()
    while GetResourceState('MULTIcore') ~= 'started' do Wait(250) end
    local ok, RedEM = pcall(function() return exports['redem_roleplay']:RedEM() end)
    if not ok or type(RedEM) ~= 'table' or not RedEM.RegisterCallback then return end
    RedEM.RegisterCallback('redemrp_inventory:server:HasItem', function(src, cb, name)
        local n = R.getItem(src, name).ItemAmount
        cb(n > 0, n)
    end)
end)
