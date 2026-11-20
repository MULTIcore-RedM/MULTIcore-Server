-- ============================================================
-- MULTIhorses :: items this resource adds
-- Horse brush, carrots, apples, hay snacks, horse meal, stimulant, reviver and
-- lantern are already in MULTIcore's items.lua. These are rsg-horses' own
-- names for horse food, so RSG scripts and old satchels that use them work too.
-- Each is registered at start through exports.MULTIinventory:RegisterItem
-- only when the registry does not have it yet. weight = grams (RSG item shape).
-- ============================================================

Config.NewItems = {
    hay         = { name = 'hay',         label = 'Hay',    weight = 300, type = 'item', image = 'hay.png',         unique = false, useable = true, shouldClose = true, description = 'A bundle of hay for horses.', category = 'horse' },
    horsecarrot = { name = 'horsecarrot', label = 'Carrot', weight = 100, type = 'item', image = 'horsecarrot.png', unique = false, useable = true, shouldClose = true, description = 'A carrot for your horse.',     category = 'horse' },
    horseapple  = { name = 'horseapple',  label = 'Apple',  weight = 100, type = 'item', image = 'horseapple.png',  unique = false, useable = true, shouldClose = true, description = 'An apple for your horse.',     category = 'horse' },
}
