-- ============================================================
-- MULTIclothing :: config
-- Every player-facing word is in locales/<lang>.lua; names below
-- (store names, groups, toggles) are locale keys.
-- Store, wardrobe and blip positions are taken from rsg-appearance's
-- config in the RSG v2 framework (GPL v3, see README credits).
-- ============================================================

Config = {}

Config.Locale = ''                -- language for this script ('' = server's multicore_locale convar, else 'en')
Config.Debug = false              -- print extra info to the server console

-- ---------------------------------------------------------------
-- How players open stores and wardrobes
-- ---------------------------------------------------------------
Config.Interact = 'auto'          -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget zone, 'prompt' = hold-to-use prompt
Config.PromptKey = 0x760A9C6F     -- prompt key: INPUT_INTERACT_OPTION1 (G), see redm-info Controls.cs
Config.PromptDistance = 2.0       -- how close (metres) the player must be for the prompt to show (prompt mode)
Config.TargetRadius = 1.2         -- MULTItarget sphere size in metres
Config.TargetDistance = 2.0       -- how close (metres) the player must stand to use the MULTItarget option
Config.TargetIconStore = 'fa-solid fa-shirt'       -- MULTItarget icon for stores
Config.TargetIconWardrobe = 'fa-solid fa-box-archive' -- MULTItarget icon for wardrobes
Config.UseRange = 3.0             -- server check: how close (metres) a player must be to a store / wardrobe

-- ---------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------
Config.Blips = {
    Stores = true,                -- show a blip on every store that has blip = true
    Wardrobes = false,            -- show a blip on wardrobe points
    Style = 1664425300,           -- blip style hash used by rsg-appearance -- UNVERIFIED (not in femga natives.json)
    StoreSprite = 1195729388,     -- clothing store sprite used by rsg-appearance -- UNVERIFIED
    WardrobeSprite = 1496995379,  -- wardrobe sprite used by rsg-appearance -- UNVERIFIED
    Scale = 0.2,                  -- blip size
}

-- ---------------------------------------------------------------
-- Clothing stores
--   name    : locale key for the store's title
--   coords  : where the prompt / target sits
--   fitting : where the player stands while trying clothes (vector4, w = heading); nil = stay put
--   exit    : where the player is placed after closing the store (vector4); nil = stay at fitting
--   blip    : show this store on the map
-- ---------------------------------------------------------------
Config.Stores = {
    valentine = {
        name = 'store_valentine',
        coords = vector3(-325.95, 806.58, 117.89),
        fitting = vector4(-327.765, 807.769, 117.894, 254.593),
        exit = vector4(-326.033, 805.976, 117.882, 241.450),
        blip = true,
    },
    rhodes = {
        name = 'store_rhodes',
        coords = vector3(1322.99, -1291.02, 77.03),
        fitting = vector4(1324.265, -1287.926, 77.018, 150.606),
        exit = vector4(1322.828, -1291.433, 77.028, 167.880),
        blip = true,
    },
    saintdenis = {
        name = 'store_saintdenis',
        coords = vector3(2554.99, -1168.60, 53.68),
        fitting = vector4(2555.500, -1161.000, 53.730, 310.371),
        exit = vector4(2553.285, -1161.101, 53.684, 96.703),
        blip = true,
    },
    blackwater = {
        name = 'store_blackwater',
        coords = vector3(-762.00, -1291.98, 43.85),
        fitting = vector4(-767.951, -1294.627, 43.835, 250.153),
        exit = vector4(-766.549, -1293.269, 43.836, 348.399),
        blip = true,
    },
    strawberry = {
        name = 'store_strawberry',
        coords = vector3(-1792.50, -392.38, 160.35),
        fitting = vector4(-1794.604, -395.540, 160.336, 317.471),
        exit = vector4(-1791.907, -391.948, 160.266, 160.266),
        blip = true,
    },
    armadillo = {
        name = 'store_armadillo',
        coords = vector3(-3687.79, -2630.85, -13.40),
        fitting = vector4(-3688.229, -2624.204, -10.218, 359.769),
        exit = vector4(-3687.822, -2630.876, -13.395, 73.005),
        blip = true,
    },
    tumbleweed = {
        name = 'store_tumbleweed',
        coords = vector3(-5480.85, -2934.57, -0.38),
        fitting = vector4(-5479.786, -2932.66, -0.283, 166.096),
        exit = vector4(-5481.510, -2935.005, -0.396, 85.180),
        blip = true,
    },
}

-- ---------------------------------------------------------------
-- Wardrobe points (saved outfits only, no shopping). Every store is a wardrobe too.
-- Positions are rsg-appearance's cloakrooms.
-- ---------------------------------------------------------------
Config.Wardrobes = {
    vector3(-325.29, 766.24, 117.48),    -- Valentine
    vector3(-1817.11, -368.77, 166.54),  -- Strawberry
    vector3(-825.40, -1323.76, 47.91),   -- Blackwater
    vector3(1331.86, -1377.35, 80.55),   -- Rhodes
    vector3(2550.67, -1159.46, 53.73),   -- Saint Denis
}

-- ---------------------------------------------------------------
-- Outfits
-- ---------------------------------------------------------------
Config.Outfits = {
    Max = 20,                     -- outfits a character may keep
    NameMax = 40,                 -- longest outfit name (characters)
    Command = false,              -- true = the command below opens the outfit list anywhere
    CommandName = 'outfits',      -- name of that command
}

-- ---------------------------------------------------------------
-- Quick toggles (take a piece off / put it back on, from the saved look; nothing is saved)
-- id = locale key 'toggle_<id>', icon = Font Awesome name, cats = look categories switched together
-- ---------------------------------------------------------------
Config.Toggles = {
    Enabled = true,               -- false = no toggle command
    Command = 'clothes',          -- command that opens the toggle menu
    Items = {
        { id = 'hat', icon = 'hat-cowboy', cats = { 'hats' } },
        { id = 'mask', icon = 'mask', cats = { 'masks' } },
        { id = 'coat', icon = 'vest', cats = { 'coats', 'coats_closed', 'ponchos', 'cloaks' } },
        { id = 'gloves', icon = 'mitten', cats = { 'gloves', 'gauntlets' } },
        { id = 'neckwear', icon = 'user-tie', cats = { 'neckwear', 'neckties' } },
        { id = 'eyewear', icon = 'glasses', cats = { 'eyewear' } },
    },
}

-- ---------------------------------------------------------------
-- Store prices (cash, dollars). A category is charged once when its piece or
-- colour changes. Taking a piece off is free.
-- ---------------------------------------------------------------
Config.Currency = '$'             -- money sign shown in the store
Config.RecolourFactor = 0.5       -- same piece, new colour only: this share of the price
Config.DefaultPrice = 2.00        -- price for any category not listed below
Config.MoneyReason = 'clothing-store' -- reason written to the money log

-- Categories in shop order. Label = locale key 'cat_<key>', group = locale key 'group_<group>',
-- cam = camera framing ('head', 'torso', 'legs', 'feet', 'full'). A category the look data has
-- but this list doesn't is still sold, in group 'other', at Config.DefaultPrice.
Config.Categories = {
    { key = 'hats',                group = 'head',     cam = 'head',  price = 5.00 },
    { key = 'eyewear',             group = 'head',     cam = 'head',  price = 2.50 },
    { key = 'masks',               group = 'head',     cam = 'head',  price = 1.50 },
    { key = 'hair_accessories',    group = 'head',     cam = 'head',  price = 1.50 },
    { key = 'neckwear',            group = 'head',     cam = 'head',  price = 1.25 },
    { key = 'neckties',            group = 'head',     cam = 'head',  price = 1.00 },

    { key = 'shirts_full',         group = 'upper',    cam = 'torso', price = 2.50 },
    { key = 'vests',               group = 'upper',    cam = 'torso', price = 3.50 },
    { key = 'suspenders',          group = 'upper',    cam = 'torso', price = 1.00 },
    { key = 'coats',               group = 'upper',    cam = 'torso', price = 12.00 },
    { key = 'coats_closed',        group = 'upper',    cam = 'torso', price = 10.00 },
    { key = 'ponchos',             group = 'upper',    cam = 'torso', price = 6.00 },
    { key = 'cloaks',              group = 'upper',    cam = 'torso', price = 8.00 },
    { key = 'dresses',             group = 'upper',    cam = 'full',  price = 14.00 },
    { key = 'armor',               group = 'upper',    cam = 'torso', price = 15.00 },
    { key = 'gloves',              group = 'upper',    cam = 'torso', price = 2.00 },
    { key = 'gauntlets',           group = 'upper',    cam = 'torso', price = 3.00 },

    { key = 'pants',               group = 'lower',    cam = 'legs',  price = 4.00 },
    { key = 'skirts',              group = 'lower',    cam = 'legs',  price = 4.00 },
    { key = 'chaps',               group = 'lower',    cam = 'legs',  price = 6.00 },
    { key = 'belts',               group = 'lower',    cam = 'legs',  price = 1.50 },
    { key = 'belt_buckles',        group = 'lower',    cam = 'legs',  price = 2.00 },

    { key = 'boots',               group = 'feet',     cam = 'feet',  price = 8.00 },
    { key = 'spats',               group = 'feet',     cam = 'feet',  price = 2.00 },
    { key = 'boot_accessories',    group = 'feet',     cam = 'feet',  price = 1.50 },

    { key = 'gunbelts',            group = 'gear',     cam = 'legs',  price = 6.00 },
    { key = 'gunbelt_accs',        group = 'gear',     cam = 'legs',  price = 1.50 },
    { key = 'holsters_left',       group = 'gear',     cam = 'legs',  price = 3.00 },
    { key = 'loadouts',            group = 'gear',     cam = 'torso', price = 4.00 },
    { key = 'satchels',            group = 'gear',     cam = 'torso', price = 3.00 },

    { key = 'accessories',         group = 'trinkets', cam = 'torso', price = 1.00 },
    { key = 'badges',              group = 'trinkets', cam = 'torso', price = 2.00 },
    { key = 'jewelry_bracelets',   group = 'trinkets', cam = 'torso', price = 4.00 },
    { key = 'jewelry_rings_left',  group = 'trinkets', cam = 'torso', price = 5.00 },
    { key = 'jewelry_rings_right', group = 'trinkets', cam = 'torso', price = 5.00 },
}
Config.OtherGroup = 'other'       -- group for categories not listed above
Config.OtherCam = 'full'          -- camera framing for those

-- Body pieces belong to the creator / barber, never sold here.
Config.NotSold = {
    heads = true, bodies_upper = true, bodies_lower = true,
    eyes = true, teeth = true, hair = true, beards_complete = true,
}

-- Palette and tint pickers (the look format stores palette + tint0..tint2 per piece)
Config.AllowColours = true        -- false = hide the colour pickers, pieces keep their own colours

-- ---------------------------------------------------------------
-- Camera framing (metres). z = height from the ped's middle, dist = distance in front, fov = zoom.
-- ---------------------------------------------------------------
Config.Camera = {
    head  = { z = 0.62, dist = 0.95, fov = 38.0 },   -- hats, eyewear, masks, neckwear
    torso = { z = 0.25, dist = 1.45, fov = 42.0 },   -- shirts, coats, gloves
    legs  = { z = -0.40, dist = 1.50, fov = 42.0 },  -- pants, belts, gunbelts
    feet  = { z = -0.80, dist = 1.15, fov = 40.0 },  -- boots, spurs
    full  = { z = 0.00, dist = 2.70, fov = 45.0 },   -- whole body
    Start = 'full',               -- framing when the store opens
    RotateStep = 15.0,            -- degrees per turn press
    Name = 'DEFAULT_SCRIPTED_CAMERA', -- camera type (as used by rsg-appearance)
}

-- ---------------------------------------------------------------
-- Timings (milliseconds)
-- ---------------------------------------------------------------
Config.Timing = {
    Fade = 300,                   -- screen fade out / in when entering and leaving the store
    FadeWaitMax = 2000,           -- longest wait for the fade to finish
    CamEase = 500,                -- camera blend in / out
    Settle = 200,                 -- pause after moving the player to the fitting spot
    DeadCheck = 500,              -- how often the open store checks whether the player died
    PreviewDelay = 90,            -- NUI waits this long after the last click before asking for a preview
}

-- ---------------------------------------------------------------
-- Menu icons (Font Awesome names, ox_lib menus)
-- ---------------------------------------------------------------
Config.Icons = {
    Store = 'shirt',              -- "Browse clothes"
    Outfits = 'box-archive',      -- "My outfits"
    Save = 'floppy-disk',         -- "Save current look"
    Outfit = 'shirt',             -- each saved outfit / "Wear"
    Rename = 'pen',               -- "Rename"
    Delete = 'trash',             -- "Delete"
    AllOn = 'rotate-left',        -- "Put everything back on"
}
