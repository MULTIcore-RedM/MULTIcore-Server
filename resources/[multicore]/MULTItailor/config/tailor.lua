Config = Config or {}

--[[
    THE TAILOR JOB

    Jobs: the global job 'tailor' works at every tailor shop; a town job (valtailor, stdentailor ...)
    only at its own town's shop. Grades: bossGrade and up (or a framework grade flagged isboss) run
    the till / boss panel. The jobs are in MULTIcore's shared/jobs.lua (tailor, valtailor ... annetailor).

    Business id of a shop = businessPrefix .. townJob ('tailor_valtailor'). The pattern book, the
    till and the counter shelf are keyed by it; the storage stash is 'multi_storage_' .. businessId.
]]
Config.Tailor = {
    tradeName = 'tailor',          -- trade id (live placement through the dynamic-location API, licence office businessId)
    label = 'Tailor',
    businessPrefix = 'tailor_',
    globalJobs = { 'tailor' },
    towns = {                      -- town job = prefix .. 'tailor'
        { prefix = 'val',    label = 'Valentine' },
        { prefix = 'black',  label = 'Blackwater' },
        { prefix = 'straw',  label = 'Strawberry' },
        { prefix = 'rhodes', label = 'Rhodes' },
        { prefix = 'stden',  label = 'Saint Denis' },
        { prefix = 'tumble', label = 'Tumbleweed' },
        { prefix = 'armad',  label = 'Armadillo' },
        { prefix = 'van',    label = 'Van Horn' },
        { prefix = 'anne',   label = 'Annesburg' },
    },
    bossGrade = 4,
    stationDistance = 4.0,         -- server: how close to a bench / counter / office a player must stand

    blips = { enabled = true, sprite = 1195729388, scale = 0.2, name = 'Tailor' },   -- blip_shop_tailor

    -- Storage stash of a shop
    storage = { label = "Tailor's Stockroom", slots = 60, maxWeight = 500000, minGrade = 0 },
}

-- ---------------------------------------------------------------- Outfit Designer
--[[
        id        framework-neutral id stored in outfit metadata (never rename once outfits exist)
        label     shown in the designer and in the item description
        vorp      clothing key of the piece (MULTIinventory equipment slot; same names vorp_character uses)
        tag       game clothing category (MULTIcore look category, MULTIData.Clothes)
        group     designer section
        keep      true = an outfit without a piece here leaves the wearer's own (gunbelt, jewellery)
        materials consumed per piece when an outfit is cut ({ item, amount })
    Which categories exist for a gentleman or a lady comes from the clothing catalogue itself
    (MULTIcore's game data), so a category with no models for a sex is hidden.
    31 categories; those with styles for each figure make the "60 catalogue categories" printed at start.
]]
Config.Designer = {
    maxPieces = 30,
    nameMaxLength = 40,
    patternsPerBusiness = 40,
    patternsTable = 'multitailor_patterns',

    -- The clothing catalogue is MULTIcore's own game data (@MULTIcore/data/clothes.lua, loaded by the
    -- fxmanifest). These two entries are only read when that data is missing.
    catalogue = {
        vorp = { resource = 'vorp_character', file = 'shared/clothing.lua' },
        rsg = { resource = 'auto', file = 'data/clothing.lua' },
    },

    -- Fitting dummy + camera
    placement = 'bench',           -- 'bench' (dummy beside the tailor) | 'fittingroom' (location designer = { ped, cam })
    hidePlayer = true,
    hideOthers = true,
    hideRadius = 15.0,
    panelShift = 0.45,
    dummyDistance = 2.0,
    minDistance = 1.3,
    camDistance = 2.6,
    fov = 42.0,
    views = {
        full = { z = 0.0, fov = 46.0 },
        head = { z = 0.65, fov = 16.0 },
        torso = { z = 0.35, fov = 26.0 },
        legs = { z = -0.45, fov = 30.0 },
    },
    rotateStep = 30.0,

    -- Dye lots. `inventory = false`: a clothing-item inventory does not accept that palette, so the
    -- piece is handed over undyed there (kept for older saved patterns).
    palettes = {
        { hash = 1090645383, label = 'Dye lot I (cloth)' },
        { hash = -783849117, label = 'Dye lot III (leather)' },
        { hash = 864404955, label = 'Dye lot IV (felt)' },
        { hash = 1669565057, label = 'Dye lot V (fine cloth)' },
        { hash = 1734720533, label = 'Dye lot VII (mixed)' },
        { hash = -183908539, label = 'Dye lot VIII (oiled leather)' },
        { hash = 1064202495, label = 'Dye lot II (old)', inventory = false, hidden = true },
        { hash = -1952348042, label = 'Dye lot VI (old trim)', inventory = false, hidden = true },
    },

    sexLabels = { male = "Gentleman's", female = "Lady's" },

    categories = {
        -- head
        { id = 'hat',        label = 'Hat',           vorp = 'Hat',        tag = 'hats',              group = 'Head',
          materials = { { item = 'wool', amount = 2 }, { item = 'leather', amount = 1 } } },
        { id = 'eyewear',    label = 'Spectacles',    vorp = 'EyeWear',    tag = 'eyewear',           group = 'Head',
          materials = { { item = 'brass_button', amount = 2 } } },
        { id = 'mask',       label = 'Mask',          vorp = 'Mask',       tag = 'masks',             group = 'Head',
          materials = { { item = 'cloth', amount = 2 } } },
        { id = 'neckwear',   label = 'Neckerchief',   vorp = 'NeckWear',   tag = 'neckwear',          group = 'Head',
          materials = { { item = 'cloth', amount = 1 } } },
        { id = 'necktie',    label = 'Necktie',       vorp = 'NeckTies',   tag = 'neckties',          group = 'Head',
          materials = { { item = 'cloth', amount = 1 } } },
        -- upper body
        { id = 'shirt',      label = 'Shirt',         vorp = 'Shirt',      tag = 'shirts_full',       group = 'Upper',
          materials = { { item = 'cloth', amount = 2 }, { item = 'cotton', amount = 1 }, { item = 'brass_button', amount = 2 } } },
        { id = 'vest',       label = 'Vest',          vorp = 'Vest',       tag = 'vests',             group = 'Upper',
          materials = { { item = 'fabric', amount = 2 }, { item = 'cloth', amount = 1 }, { item = 'brass_button', amount = 3 } } },
        { id = 'suspenders', label = 'Suspenders',    vorp = 'Suspender',  tag = 'suspenders',        group = 'Upper',
          materials = { { item = 'leather', amount = 1 }, { item = 'brass_button', amount = 2 } } },
        { id = 'coat',       label = 'Coat',          vorp = 'Coat',       tag = 'coats',             group = 'Upper',
          materials = { { item = 'fabric', amount = 4 }, { item = 'wool', amount = 2 }, { item = 'cloth', amount = 1 }, { item = 'brass_button', amount = 4 } } },
        { id = 'coat_closed', label = 'Buttoned Coat', vorp = 'CoatClosed', tag = 'coats_closed',     group = 'Upper',
          materials = { { item = 'fabric', amount = 4 }, { item = 'wool', amount = 2 }, { item = 'cloth', amount = 1 }, { item = 'brass_button', amount = 6 } } },
        { id = 'poncho',     label = 'Poncho',        vorp = 'Poncho',     tag = 'ponchos',           group = 'Upper',
          materials = { { item = 'wool', amount = 4 }, { item = 'twine', amount = 1 } } },
        { id = 'cloak',      label = 'Cloak',         vorp = 'Cloak',      tag = 'cloaks',            group = 'Upper',
          materials = { { item = 'wool', amount = 3 }, { item = 'fabric', amount = 2 }, { item = 'tanned_fur', amount = 1 } } },
        { id = 'dress',      label = 'Dress',         vorp = 'Dress',      tag = 'dresses',           group = 'Upper',
          materials = { { item = 'fabric', amount = 5 }, { item = 'cloth', amount = 2 }, { item = 'twine', amount = 1 }, { item = 'brass_button', amount = 4 } } },
        -- lower body
        { id = 'pants',      label = 'Trousers',      vorp = 'Pant',       tag = 'pants',             group = 'Lower',
          materials = { { item = 'fabric', amount = 3 }, { item = 'twine', amount = 1 }, { item = 'brass_button', amount = 2 } } },
        { id = 'skirt',      label = 'Skirt',         vorp = 'Skirt',      tag = 'skirts',            group = 'Lower',
          materials = { { item = 'fabric', amount = 3 }, { item = 'twine', amount = 1 } } },
        { id = 'chaps',      label = 'Chaps',         vorp = 'Chap',       tag = 'chaps',             group = 'Lower',
          materials = { { item = 'leather', amount = 3 }, { item = 'twine', amount = 1 } } },
        { id = 'spats',      label = 'Spats',         vorp = 'Spats',      tag = 'spats',             group = 'Lower',
          materials = { { item = 'cloth', amount = 1 }, { item = 'brass_button', amount = 2 } } },
        { id = 'boots',      label = 'Boots',         vorp = 'Boots',      tag = 'boots',             group = 'Lower',
          materials = { { item = 'leather', amount = 2 }, { item = 'twine', amount = 1 } } },
        { id = 'spurs',      label = 'Spurs',         vorp = 'Spurs',      tag = 'boot_accessories',  group = 'Lower',
          materials = { { item = 'brass_button', amount = 3 } } },
        -- hands & jewellery
        { id = 'gloves',     label = 'Gloves',        vorp = 'Glove',      tag = 'gloves',            group = 'Hands',
          materials = { { item = 'leather', amount = 1 } } },
        { id = 'gauntlets',  label = 'Gauntlets',     vorp = 'Gauntlets',  tag = 'gauntlets',         group = 'Hands',
          materials = { { item = 'leather', amount = 2 } } },
        { id = 'bracelet',   label = 'Bracelet',      vorp = 'Bracelet',   tag = 'jewelry_bracelets', group = 'Hands', keep = true,
          materials = { { item = 'brass_button', amount = 2 } } },
        { id = 'ring_r',     label = 'Ring (right)',  vorp = 'RingRh',     tag = 'jewelry_rings_right', group = 'Hands', keep = true,
          materials = { { item = 'brass_button', amount = 1 } } },
        { id = 'ring_l',     label = 'Ring (left)',   vorp = 'RingLh',     tag = 'jewelry_rings_left', group = 'Hands', keep = true,
          materials = { { item = 'brass_button', amount = 1 } } },
        -- belts & gear
        { id = 'belt',       label = 'Belt',          vorp = 'Belt',       tag = 'belts',             group = 'Gear',
          materials = { { item = 'leather', amount = 1 } } },
        { id = 'buckle',     label = 'Belt Buckle',   vorp = 'Buckle',     tag = 'belt_buckles',      group = 'Gear',
          materials = { { item = 'brass_button', amount = 2 } } },
        { id = 'gunbelt',    label = 'Gunbelt',       vorp = 'Gunbelt',    tag = 'gunbelts',          group = 'Gear', keep = true,
          materials = { { item = 'leather', amount = 3 }, { item = 'brass_button', amount = 2 } } },
        { id = 'holster',    label = 'Holster',       vorp = 'Holster',    tag = 'holsters_left',     group = 'Gear', keep = true,
          materials = { { item = 'leather', amount = 2 } } },
        { id = 'loadouts',   label = 'Bandolier',     vorp = 'Loadouts',   tag = 'loadouts',          group = 'Gear', keep = true,
          materials = { { item = 'leather', amount = 2 }, { item = 'twine', amount = 1 } } },
        { id = 'satchel',    label = 'Satchel',       vorp = 'Satchels',   tag = 'satchels',          group = 'Gear', keep = true,
          materials = { { item = 'leather', amount = 2 }, { item = 'twine', amount = 1 } } },
        { id = 'accessories', label = 'Accessories',  vorp = 'Accessories', tag = 'accessories',      group = 'Gear',
          materials = { { item = 'cloth', amount = 1 } } },
    },
}

-- ---------------------------------------------------------------- Sewing (bench recipes + minigame)
--[[
    The cutting table also sews the cloth and notions the garments use. Every sewing job (a recipe
    batch or cutting an outfit) is a short needlework minigame (ox_lib skill checks, one per round).
    The share of rounds hit sets the quality of a cut outfit; a recipe batch that misses every round
    yields half. The server times every session (a reply faster than minMsPerRound per round is refused).
]]
Config.Sewing = {
    rounds = { 'easy', 'easy', 'medium' },
    keys = { 'w', 'a', 's', 'd' },
    minMsPerRound = 350,
    sessionTtl = 120,              -- seconds a started session stays valid
    maxBatch = 10,
    craftMsPerUnit = 2500,         -- progress bar per unit after the minigame

    quality = {                    -- by share of rounds hit (outfits)
        { id = 'poor',       min = 0.0,  label = 'Rough' },
        { id = 'standard',   min = 0.34, label = 'Standard' },
        { id = 'fine',       min = 0.66, label = 'Fine' },
        { id = 'masterwork', min = 1.0,  label = 'Masterwork' },
    },

    -- Cotton, wool, twine and copper come from farms, ranches, mines and trade shops.
    recipes = {
        { id = 'fabric', label = 'Bolt of Fabric', receive = 'fabric', amount = 2,
          required = { { item = 'cotton', amount = 3 }, { item = 'twine', amount = 1 } } },
        { id = 'cloth', label = 'Woollen Cloth', receive = 'cloth', amount = 4,
          required = { { item = 'wool', amount = 3 }, { item = 'twine', amount = 1 } } },
        { id = 'brass_button', label = 'Brass Buttons', receive = 'brass_button', amount = 6,
          required = { { item = 'copper', amount = 1 } } },
    },
}

-- ---------------------------------------------------------------- The tailor's counter
--[[
    Staff put finished garments (and cloth) on the counter shelf at a price; anyone buys them there.
    Money goes into the shop's till (boss panel). Customers can also leave a written order.
]]
Config.Counter = {
    maxLines = 80,                 -- shelf lines per shop
    minPrice = 0.05,
    maxPrice = 2500.0,
    -- what may be put on the shelf (Lua patterns on the item name)
    allowed = { '^tailored_outfit$', '^npc_garment$', '^npc_outfit$', '^clothing_', '^fabric$', '^cloth$', '^brass_button$', '^wool$', '^cotton$', '^twine$' },
    -- default ask shown for an outfit when stocking: materials x markup
    suggestedMarkup = 12.5,         -- materials are cheap; the rest is the tailor's skill and time
    qualityMarkup = { poor = 0.8, standard = 1.0, fine = 1.25, masterwork = 1.6 },
    -- material prices used for that suggestion (1910, about $20/h; same as the supply catalogues)
    materialPrices = {
        cotton = 0.12, wool = 0.25, twine = 0.30, cloth = 0.50, fabric = 0.50, leather = 2.00,
        copper = 0.30, brass_button = 0.05, tanned_fur = 1.50,
    },
    -- default shelf price offered when staff stock these (they set their own)
    defaultPrices = { fabric = 0.60, cloth = 0.60, brass_button = 0.06, wool = 0.30, cotton = 0.15, twine = 0.35 },
}

Config.Orders = {
    enabled = true,
    maxOpenPerCustomer = 2,
    textMax = 300,
    keepDays = 21,                 -- finished / cancelled orders are pruned after this
    perShop = 40,
}

Config.Till = {
    maxTransaction = 5000.0,
    historyRows = 25,
}
