-- ============================================================
-- MULTIinventory :: engine exports
-- Every MULTIInv function is also exports.MULTIinventory:<Name>(...).
-- Weapon helpers: exports.MULTIinventory:WeaponNew(name, info),
-- WeaponFindById(id), WeaponFindBySerial(serial), WeaponNewSerial().
-- Data: GetWeaponData(), GetAmmoData(), GetItems(), IsReady().
-- Note: across resources tables are copies; change items only through the API.
-- ============================================================

local Inv = MULTIInv

-- registered after every core file has run (this file loads last in server/core)
for name, fn in pairs(Inv) do
    if type(fn) == 'function' and not name:find('^_') and not name:find('_$') then
        exports(name, fn)
    end
end
for name, fn in pairs(Inv.Weapon) do
    if type(fn) == 'function' and not name:find('^_') then exports('Weapon' .. name, fn) end
end

exports('GetWeaponData', function(name)
    if name then return MULTIInvData.GetWeapon(name) end
    return MULTIInvData.Weapons
end)
exports('GetAmmoData', function()
    return { ammo = MULTIInvData.Ammo, items = MULTIInvData.AmmoItems, boxes = MULTIInvData.AmmoBoxes }
end)
exports('GetItems', function() return Inv.Items end)
exports('IsReady', function() return Inv.ready end)
