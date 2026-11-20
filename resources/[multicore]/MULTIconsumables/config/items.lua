-- ============================================================
-- MULTIconsumables :: items this resource adds
-- The same items are in MULTIcore's shared/items.lua (RSG shape), so RSG scripts and the
-- stores see them from the start. At start MULTIconsumables registers any of these that the
-- registry does not have yet through exports.MULTIinventory:RegisterItem (an item already
-- defined, e.g. in your own items.lua or VORP's items table, is left as it is).
-- weight = grams. Labels and descriptions are English, like RSG's items.lua.
-- ============================================================

Config.NewItems = {
    -- spirits and wine (beer is already in MULTIcore's items.lua)
    whiskey          = { name = 'whiskey',          label = 'Whiskey',          weight = 1000, type = 'item', image = 'whiskey.png',          unique = false, useable = true,  shouldClose = true, description = 'A bottle of Kentucky whiskey. Warms the belly, clouds the head.', category = 'consumable' },
    rum              = { name = 'rum',              label = 'Rum',              weight = 1000, type = 'item', image = 'rum.png',              unique = false, useable = true,  shouldClose = true, description = 'Dark navy rum shipped up from the islands.', category = 'consumable' },
    gin              = { name = 'gin',              label = 'Gin',              weight = 1000, type = 'item', image = 'gin.png',              unique = false, useable = true,  shouldClose = true, description = 'Dry gin with a sharp taste of juniper.', category = 'consumable' },
    moonshine        = { name = 'moonshine',        label = 'Moonshine',        weight = 1500, type = 'item', image = 'moonshine.png',        unique = false, useable = true,  shouldClose = true, description = 'Clear corn liquor from a back-country still. Very strong.', category = 'consumable' },
    wine             = { name = 'wine',             label = 'Wine',             weight = 1000, type = 'item', image = 'wine.png',             unique = false, useable = true,  shouldClose = true, description = 'A bottle of red table wine.', category = 'consumable' },
    -- tobacco
    cigarettes       = { name = 'cigarettes',       label = 'Cigarettes',       weight = 30,   type = 'item', image = 'cigarettes.png',       unique = false, useable = true,  shouldClose = true, description = 'A pack of hand-rolled cigarettes.', category = 'consumable' },
    cigar            = { name = 'cigar',            label = 'Cigar',            weight = 20,   type = 'item', image = 'cigar.png',            unique = false, useable = true,  shouldClose = true, description = 'A fine cigar for a quiet moment.', category = 'consumable' },
    pipe             = { name = 'pipe',             label = 'Pipe',             weight = 60,   type = 'item', image = 'pipe.png',             unique = false, useable = false, shouldClose = true, description = 'A briar smoking pipe. Needs pipe tobacco.', category = 'consumable' },
    pipe_tobacco     = { name = 'pipe_tobacco',     label = 'Pipe Tobacco',     weight = 50,   type = 'item', image = 'pipe_tobacco.png',     unique = false, useable = true,  shouldClose = true, description = 'A pouch of cut pipe tobacco. Smoke it with a pipe.', category = 'consumable' },
    chewing_tobacco  = { name = 'chewing_tobacco',  label = 'Chewing Tobacco',  weight = 50,   type = 'item', image = 'chewing_tobacco.png',  unique = false, useable = true,  shouldClose = true, description = 'A tin of chewing tobacco.', category = 'consumable' },
    -- medicine
    laudanum         = { name = 'laudanum',         label = 'Laudanum',         weight = 120,  type = 'item', image = 'laudanum.png',         unique = false, useable = true,  shouldClose = true, description = 'Tincture of opium sold for pain and sleeplessness. Habit-forming.', category = 'medical' },
    tonic_temperance = { name = 'tonic_temperance', label = 'Temperance Tonic', weight = 150,  type = 'item', image = 'tonic_temperance.png', unique = false, useable = true,  shouldClose = true, description = 'A doctor\'s remedy that eases the craving for drink and laudanum.', category = 'medical' },
}
