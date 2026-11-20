-- ============================================================
-- MULTIinventory :: vorp_inventory face - the old VORP API
-- Older VORP scripts use server events ('vorpCore:addItem', ...) with a
-- callback, or an API object from exports.vorp_inventory:vorp_inventoryApi().
-- Both are thin wrappers over the exports in this folder.
-- (No caller of these was found on the reference server; they follow
-- VORP's older public README. Server-side events only: TriggerEvent.)
-- ============================================================

local V = MULTIVorp
local I, W, C = V.Items, V.Weapons, V.Customs

local function call(cb, value)
    return V.Done(cb, value)
end

-- event name -> handler
local events = {
    ['vorpCore:addItem']          = function(src, item, amount, metadata, cb) return call(cb, I.addItem(src, item, amount, metadata)) end,
    ['vorpCore:subItem']          = function(src, item, amount, metadata, cb) return call(cb, I.subItem(src, item, amount, metadata)) end,
    ['vorpCore:subItemID']        = function(src, id, cb) return call(cb, I.subItemById(src, id)) end,
    ['vorpCore:getItemCount']     = function(src, cb, item, metadata) return call(cb, I.getItemCount(src, nil, item, metadata)) end,
    ['vorpCore:getItem']          = function(src, item, cb, metadata) return call(cb, I.getItem(src, item, nil, metadata)) end,
    ['vorpCore:getUserInventory'] = function(src, cb) return call(cb, I.getUserInventoryItems(src)) end,
    ['vorpCore:canCarryItems']    = function(src, amount, cb) return call(cb, I.canCarryItems(src, amount)) end,
    ['vorpCore:canCarryItem']     = function(src, item, amount, cb) return call(cb, I.canCarryItem(src, item, amount)) end,
    ['vorpCore:registerUsableItem'] = function(item, cb) return I.registerUsableItem(item, cb) end,
    ['vorpCore:getItemDB']        = function(item, cb) return call(cb, I.getItemDB(item)) end,
    ['vorpCore:createWeapon']     = function(src, name, ammo, components, cb) return call(cb, W.createWeapon(src, name, ammo, components)) end,
    ['vorpCore:giveWeapon']       = function(src, weaponId, target, cb) return call(cb, W.giveWeapon(src, weaponId, target)) end,
    ['vorpCore:subWeapon']        = function(src, weaponId, cb) return call(cb, W.subWeapon(src, weaponId)) end,
    ['vorpCore:getUserWeapons']   = function(src, cb) return call(cb, W.getUserInventoryWeapons(src)) end,
    ['vorpCore:getUserWeapon']    = function(src, cb, weaponId) return call(cb, W.getUserWeapon(src, nil, weaponId)) end,
    ['vorpCore:canCarryWeapons']  = function(src, amount, cb, name) return call(cb, W.canCarryWeapons(src, amount, nil, name)) end,
    ['vorpCore:getWeaponBullets'] = function(src, cb, weaponId) return call(cb, W.getWeaponBullets(src, weaponId)) end,
    ['vorpCore:getWeaponComponents'] = function(src, cb, weaponId) return call(cb, W.getWeaponComponents(src, weaponId)) end,
    ['vorpCore:addBullets']       = function(src, bulletType, amount, cb) return call(cb, W.addBullets(src, bulletType, amount)) end,
    ['vorpCore:subBullets']       = function(src, weaponId, bulletType, amount, cb) return call(cb, W.subBullets(src, weaponId, bulletType, amount)) end,
    ['vorpCore:getUserAmmo']      = function(src, cb) return call(cb, W.getUserAmmo(src)) end,
    ['vorpCore:removeAllUserAmmo'] = function(src) return W.removeAllUserAmmo(src) end,
    ['vorpCore:openInventory']    = function(src, id) return C.openInventory(src, id) end,
    ['vorpCore:closeInventory']   = function(src) return C.closeInventory(src) end,
}

for name, fn in pairs(events) do
    -- server side only: a client must never reach these
    AddEventHandler(name, function(...)
        local ok, err = pcall(fn, ...)
        if not ok then V.Warn('%s failed: %s', name, tostring(err)) end
    end)
end

-- ------------------------------------------------------------
-- exports.vorp_inventory:vorp_inventoryApi() - the object old scripts keep
-- (methods called with a dot, no callbacks, values returned)
-- ------------------------------------------------------------
local Api = {
    addItem = function(src, item, amount, metadata) return I.addItem(src, item, amount, metadata) end,
    subItem = function(src, item, amount, metadata) return I.subItem(src, item, amount, metadata) end,
    subItemID = function(src, id) return I.subItemById(src, id) end,
    getItemCount = function(src, item, metadata) return I.getItemCount(src, nil, item, metadata) end,
    getItem = function(src, item, metadata) return I.getItem(src, item, nil, metadata) end,
    getItemByMainId = function(src, id) return I.getItemById(src, id) end,
    getUserInventory = function(src) return I.getUserInventoryItems(src) end,
    canCarryItems = function(src, amount) return I.canCarryItems(src, amount) end,
    canCarryItem = function(src, item, amount) return I.canCarryItem(src, item, amount) end,
    RegisterUsableItem = function(item, cb) return I.registerUsableItem(item, cb) end,
    getDBItem = function(_, item) return I.getItemDB(item) end,
    setItemMetadata = function(src, id, metadata) return I.setItemMetadata(src, id, metadata) end,
    createWeapon = function(src, name, ammo, components) return W.createWeapon(src, name, ammo, components) end,
    giveWeapon = function(src, weaponId, target) return W.giveWeapon(src, weaponId, target) end,
    subWeapon = function(src, weaponId) return W.subWeapon(src, weaponId) end,
    getWeaponBullets = function(src, weaponId) return W.getWeaponBullets(src, weaponId) end,
    getWeaponComponents = function(src, weaponId) return W.getWeaponComponents(src, weaponId) end,
    getUserWeapons = function(src) return W.getUserInventoryWeapons(src) end,
    getUserWeapon = function(src, weaponId) return W.getUserWeapon(src, nil, weaponId) end,
    canCarryWeapons = function(src, amount, name) return W.canCarryWeapons(src, amount, nil, name) end,
    addBullets = function(src, bulletType, amount) return W.addBullets(src, bulletType, amount) end,
    subBullets = function(src, weaponId, bulletType, amount) return W.subBullets(src, weaponId, bulletType, amount) end,
    getUserAmmo = function(src) return W.getUserAmmo(src) end,
    CloseInv = function(src) return C.closeInventory(src) end,
    OpenInv = function(src) return C.openInventory(src) end,
    registerInventory = function(id, name, limit, acceptWeapons, shared, ignoreItemStackLimit)
        if type(id) == 'table' then return C.registerInventory(id) end
        return C.registerInventory({ id = id, name = name, limit = limit, acceptWeapons = acceptWeapons, shared = shared, ignoreItemStackLimit = ignoreItemStackLimit })
    end,
    removeInventory = function(id) return C.removeInventory(id) end,
    openInventory = function(src, id) return C.openInventory(src, id) end,
    closeInventory = function(src) return C.closeInventory(src) end,
}
V.Api = Api

V.Export('vorp_inventoryApi', function() return Api end)
