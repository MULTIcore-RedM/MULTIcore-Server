-- ============================================================
-- MULTIcrafting :: recipes
-- One entry per recipe:
--   id        unique name (keep it stable; other scripts and logs use it)
--   label     locale key or plain text for the menu (nil = the output item's label)
--   category  group shown in the menu (locale key cat_<category>; nil = 'other')
--   stations  station types where it can be made: 'hand', 'campfire', 'cooking', 'gunsmith', 'blacksmith'
--             (types are in config.lua Config.StationTypes; fixed stations in config/stations.lua)
--   inputs    { { item = 'name', amount = n }, ... }   taken when crafting finishes
--   output    { item = 'name', amount = n }             given when crafting finishes
--   time      seconds for one craft (crafting several at once takes time x count)
--   job       optional: MULTIcore job name (or a list of names) that may make it
--   grade     optional: lowest job grade (number) that may make it (default 0)
--   tool      optional: item needed in the satchel; it is kept (e.g. a knife)
--
-- Every item named here must exist in MULTIinventory's registry (MULTIcore items, VORP's items
-- table, or config/items.lua). A recipe with an unknown item is skipped with a warning at start.
-- Ammo outputs are MULTIinventory's round items (ammo_revolver, ammo_arrow_single ...).
-- ============================================================

Config.Recipes = {
    ---------------------------------------------------------------- food (campfire, kitchen)
    {
        id = 'cooked_meat', category = 'food', stations = { 'campfire', 'cooking' }, time = 8,
        inputs = { { item = 'raw_meat', amount = 1 } },
        output = { item = 'cooked_meat', amount = 1 },
    },
    {
        id = 'cooked_fish', category = 'food', stations = { 'campfire', 'cooking' }, time = 8,
        inputs = { { item = 'raw_fish', amount = 1 } },
        output = { item = 'cooked_fish', amount = 1 },
    },
    {
        id = 'stew', category = 'food', stations = { 'campfire', 'cooking' }, time = 15,
        inputs = { { item = 'raw_meat', amount = 1 }, { item = 'herb_wild_carrot', amount = 2 }, { item = 'water', amount = 1 } },
        output = { item = 'stew', amount = 1 },
    },
    {
        id = 'bread', category = 'food', stations = { 'cooking' }, time = 12,
        inputs = { { item = 'flour_wheat', amount = 1 }, { item = 'egg', amount = 1 }, { item = 'water', amount = 1 } },
        output = { item = 'bread', amount = 2 },
    },

    ---------------------------------------------------------------- satchel (hand)
    {
        id = 'bandage', category = 'medical', stations = { 'hand', 'campfire' }, time = 5,
        inputs = { { item = 'cloth', amount = 2 } },
        output = { item = 'bandage', amount = 1 },
    },
    {
        id = 'arrows', category = 'ammo', stations = { 'hand', 'campfire' }, time = 6, tool = 'weapon_melee_knife',
        inputs = { { item = 'feather', amount = 1 }, { item = 'wood', amount = 1 } },
        output = { item = 'ammo_arrow_single', amount = 2 },
    },
    {
        id = 'campfire_kit', category = 'camp', stations = { 'hand' }, time = 5,
        inputs = { { item = 'wood', amount = 4 } },
        output = { item = 'campfire', amount = 1 },
    },

    ---------------------------------------------------------------- gunsmith bench (gunsmiths only)
    {
        id = 'gunpowder', category = 'material', stations = { 'gunsmith' }, time = 10, job = 'gunsmith',
        inputs = { { item = 'resource_sulfur', amount = 1 }, { item = 'resource_nitrate', amount = 1 }, { item = 'resource_coal', amount = 1 } },
        output = { item = 'gunpowder', amount = 2 },
    },
    {
        id = 'ammo_revolver', category = 'ammo', stations = { 'gunsmith' }, time = 10, job = 'gunsmith',
        inputs = { { item = 'gunpowder', amount = 1 }, { item = 'resource_lead_bar', amount = 1 } },
        output = { item = 'ammo_revolver', amount = 12 },
    },
    {
        id = 'ammo_pistol', category = 'ammo', stations = { 'gunsmith' }, time = 10, job = 'gunsmith',
        inputs = { { item = 'gunpowder', amount = 1 }, { item = 'resource_lead_bar', amount = 1 } },
        output = { item = 'ammo_pistol', amount = 12 },
    },
    {
        id = 'ammo_repeater', category = 'ammo', stations = { 'gunsmith' }, time = 10, job = 'gunsmith',
        inputs = { { item = 'gunpowder', amount = 1 }, { item = 'resource_lead_bar', amount = 1 } },
        output = { item = 'ammo_repeater', amount = 12 },
    },
    {
        id = 'ammo_rifle', category = 'ammo', stations = { 'gunsmith' }, time = 12, job = 'gunsmith',
        inputs = { { item = 'gunpowder', amount = 2 }, { item = 'resource_lead_bar', amount = 1 } },
        output = { item = 'ammo_rifle', amount = 12 },
    },
    {
        id = 'ammo_shotgun', category = 'ammo', stations = { 'gunsmith' }, time = 12, job = 'gunsmith',
        inputs = { { item = 'gunpowder', amount = 2 }, { item = 'resource_lead_bar', amount = 1 } },
        output = { item = 'ammo_shotgun', amount = 12 },
    },

    ---------------------------------------------------------------- blacksmith (smiths only)
    {
        id = 'knife', category = 'tools', stations = { 'blacksmith' }, time = 20, job = 'blacksmith',
        inputs = { { item = 'resource_iron_bar', amount = 1 }, { item = 'resource_coal', amount = 1 }, { item = 'wood', amount = 1 } },
        output = { item = 'weapon_melee_knife', amount = 1 },
    },
    {
        id = 'axe', category = 'tools', stations = { 'blacksmith' }, time = 25, job = 'blacksmith',
        inputs = { { item = 'resource_iron_bar', amount = 2 }, { item = 'resource_coal', amount = 1 }, { item = 'wood', amount = 2 } },
        output = { item = 'axe', amount = 1 },
    },
    {
        id = 'pickaxe', category = 'tools', stations = { 'blacksmith' }, time = 25, job = 'blacksmith',
        inputs = { { item = 'resource_iron_bar', amount = 2 }, { item = 'resource_coal', amount = 1 }, { item = 'wood', amount = 2 } },
        output = { item = 'pickaxe', amount = 1 },
    },
    {
        id = 'shovel', category = 'tools', stations = { 'blacksmith' }, time = 20, job = 'blacksmith',
        inputs = { { item = 'resource_iron_bar', amount = 1 }, { item = 'resource_coal', amount = 1 }, { item = 'wood', amount = 2 } },
        output = { item = 'shovel', amount = 1 },
    },
}
