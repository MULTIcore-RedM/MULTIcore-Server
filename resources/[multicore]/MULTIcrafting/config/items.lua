-- ============================================================
-- MULTIcrafting :: items this resource adds
-- Only the basic materials the starter recipes need that MULTIcore's items do not have.
-- At start each one is registered through exports.MULTIinventory:RegisterItem when the registry
-- does not have it yet (an item already defined, e.g. in your own items.lua or VORP's items
-- table, is left as it is). RSG item shape; weight = grams. Labels are English, like RSG's items.lua.
-- ============================================================

Config.NewItems = {
    cloth     = { name = 'cloth',     label = 'Cloth',     weight = 50,  type = 'item', image = 'cloth.png',     unique = false, useable = false, shouldClose = true, description = 'A strip of plain cotton cloth.', category = 'material' },
    gunpowder = { name = 'gunpowder', label = 'Gunpowder', weight = 100, type = 'item', image = 'gunpowder.png', unique = false, useable = false, shouldClose = true, description = 'Black powder for loading cartridges. Keep it dry.', category = 'material' },
}
