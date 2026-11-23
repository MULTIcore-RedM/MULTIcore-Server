Config = Config or {}

--[[
    PUBLIC CLOTHES STORES - ready-made basics sold by an NPC clerk.

    Plain, cheap, few styles: hats, shirts, vests, coats, trousers, skirts, boots, gloves,
    neckwear, belts, suspenders. No dyes, no fine cloth - made-to-measure and fancy garments
    are the player tailors' trade (Outfit Designer), and cost more there.

    Stores: the clerk stands at `clerk` (vector4, heading). Target the clerk (MULTItarget, or the key
    prompt) -> "Browse ready-made clothes": a try-on panel with the camera on yourself, buy -> the
    garment goes into your satchel as a clothing item (use it, or drag it to its equipment slot, to wear it).
    The clerk also opens "My outfits" (Config.Stores.outfitsAtClerk).
    Staff with the admin ACE move / add / hide stores live: /tailorstores (menu). Those
    changes are saved in the database (multitailor_stores) and win over this file.

    Coordinates: the seven towns with a clothing store stand at that store's counter (Valentine at
    the store point MULTIcore used before); Annesburg and Van Horn stand in the general store and
    the trading post. These are default positions: check them in game and adjust to your map if needed.
]]
Config.Stores = {
    enabled = true,
    interactDistance = 2.5,
    serverDistance = 6.0,          -- server check: buyer within this many metres of the clerk
    defaultModel = 'u_m_m_valtownfolk_01',
    fallbackModels = { 'u_m_m_valtownfolk_01', 'a_m_m_valtownfolk_01' },
    blip = { enabled = true, sprite = 1195729388, scale = 0.2, name = 'Clothes Store' },
    priceMultiplier = 1.0,         -- every store, every line
    -- Stock: 0 = unlimited. Otherwise each line (style + colour) holds this many per store and
    -- refills `restockAmount` every `restockMinutes` (kept in memory; full again after a restart).
    stockPerLine = 0,
    restockMinutes = 30,
    restockAmount = 2,
    maxPerPurchase = 1,

    -- Try-on camera (on the player)
    camera = {
        distance = 2.3,
        fov = 40.0,
        views = {
            full = { z = 0.0, fov = 45.0 },
            head = { z = 0.62, fov = 16.0 },
            torso = { z = 0.3, fov = 26.0 },
            legs = { z = -0.5, fov = 30.0 },
        },
        rotateStep = 30.0,
        panelShift = 0.45,
    },
    outfitsAtClerk = true,         -- the clerk also opens the saved outfit list

    list = {
        { id = 'valentine',  label = 'Valentine Clothier',             town = 'Valentine',
          clerk = vector4(-325.95, 806.58, 117.89, 61.0) },     -- store point; heading: check in game
        { id = 'saintdenis', label = 'Saint Denis Ready-to-Wear',      town = 'Saint Denis', priceMultiplier = 1.10,
          clerk = vector4(2552.89, -1163.73, 53.73, 143.93) },
        { id = 'blackwater', label = 'Blackwater Clothier',            town = 'Blackwater',
          clerk = vector4(-761.31, -1293.64, 43.84, 6.33) },
        { id = 'rhodes',     label = 'Rhodes Dry Goods & Clothing',    town = 'Rhodes',
          clerk = vector4(1323.02, -1292.14, 77.08, 239.01) },
        { id = 'strawberry', label = 'Strawberry Outfitters',          town = 'Strawberry',
          clerk = vector4(-1791.07, -392.71, 160.29, 326.21) },
        { id = 'tumbleweed', label = 'Tumbleweed Outfitter',           town = 'Tumbleweed',
          clerk = vector4(-5484.07, -2932.47, -0.35, 188.13) },
        { id = 'armadillo',  label = 'Armadillo Clothing',             town = 'Armadillo',
          clerk = vector4(-3686.39, -2628.62, -13.38, 319.32) },
        { id = 'annesburg',  label = 'Annesburg Work Clothes',         town = 'Annesburg',
          clerk = vector4(2933.60, 1364.80, 44.20, 90.0) },     -- general store - default position, check in game
        { id = 'vanhorn',    label = 'Van Horn Slops & Clothing',      town = 'Van Horn',
          clerk = vector4(3025.40, 562.60, 43.72, 250.0) },     -- trading post - default position, check in game
    },

    -- Price per category ($, 1910, about $20/h; clothing $5-150). Below the player tailors' price for the same garment
    -- (materials x markup) - ready-made is plain, cheap and undyed.
    -- In the full catalogue every category with a price here is for sale; leave one out (or set it to 0) to keep
    -- that kind of piece off the store shelves (the player tailors can still make it).
    prices = {
        -- head & neck
        hat = 18.00, eyewear = 6.00, mask = 4.00, neckwear = 5.00, necktie = 5.00,
        -- shirts, vests & coats
        shirt = 12.00, vest = 15.00, suspenders = 6.00, coat = 35.00, coat_closed = 40.00,
        poncho = 20.00, cloak = 30.00, dress = 45.00,
        -- trousers, skirts & boots
        pants = 18.00, skirt = 18.00, chaps = 22.00, spats = 8.00, boots = 30.00, spurs = 10.00,
        -- gloves & jewellery
        gloves = 10.00, gauntlets = 14.00, bracelet = 12.00, ring_r = 15.00, ring_l = 15.00,
        -- belts & gear
        belt = 8.00, buckle = 6.00, gunbelt = 25.00, holster = 12.00, loadouts = 15.00, satchel = 20.00,
        accessories = 8.00,
    },

    -- Full catalogue: the store shows every style and every colour the game has, in every priced category
    -- (as many as the tailor's Outfit Designer: thousands of pieces). Pick a style and a colour with the arrows,
    -- it is tried on you at once, buy it. false = only the ready-made lines in `catalogue` below.
    fullCatalogue = true,

    --[[
        Catalogue lines. sex = 'male' | 'female'; cat = a Config.Designer.categories id.
        model  = the style's game item name (its _TINT_ number dropped), or
        m      = the style's index in the catalogue (for styles without an item name, e.g. belts).
        colours = which colour variants (1 = first) are sold. price overrides the category price.
        Lines whose style is not in the running catalogue are skipped (printed at start).
    ]]
    catalogue = {
        -- ------------------------------------------------ gentlemen
        { id = 'm_hat_a',     sex = 'male', cat = 'hat',        model = 'CLOTHING_ITEM_M_HAT_000',        colours = { 1, 2, 3, 4 }, label = 'Felt Hat' },
        { id = 'm_hat_b',     sex = 'male', cat = 'hat',        model = 'CLOTHING_ITEM_M_HAT_001',        colours = { 1, 2, 3 },    label = 'Working Hat' },
        { id = 'm_hat_c',     sex = 'male', cat = 'hat',        model = 'CLOTHING_ITEM_M_HAT_002',        colours = { 1, 2, 3 },    label = 'Town Hat' },
        { id = 'm_shirt_a',   sex = 'male', cat = 'shirt',      model = 'CLOTHING_ITEM_M_SHIRT_000',      colours = { 1, 2, 3, 4 }, label = 'Cotton Work Shirt' },
        { id = 'm_shirt_b',   sex = 'male', cat = 'shirt',      model = 'CLOTHING_ITEM_M_SHIRT_001',      colours = { 1, 2, 3 },    label = 'Plain Shirt' },
        { id = 'm_shirt_c',   sex = 'male', cat = 'shirt',      model = 'CLOTHING_ITEM_M_SHIRT_002',      colours = { 1, 2, 3 },    label = 'Collared Shirt' },
        { id = 'm_vest_a',    sex = 'male', cat = 'vest',       model = 'CLOTHING_ITEM_M_VEST_000',       colours = { 1, 2, 3 },    label = 'Plain Vest' },
        { id = 'm_vest_b',    sex = 'male', cat = 'vest',       model = 'CLOTHING_ITEM_M_VEST_001',       colours = { 1, 2 },       label = 'Wool Vest' },
        { id = 'm_coat_a',    sex = 'male', cat = 'coat',       model = 'CLOTHING_ITEM_M_COAT_000',       colours = { 1, 2, 3 },    label = 'Sack Coat' },
        { id = 'm_coat_b',    sex = 'male', cat = 'coat',       model = 'CLOTHING_ITEM_M_COAT_001',       colours = { 1, 2 },       label = 'Work Coat' },
        { id = 'm_ccoat_a',   sex = 'male', cat = 'coat_closed', model = 'CLOTHING_ITEM_M_CLOSECOAT_000', colours = { 1, 2, 3 },    label = 'Buttoned Overcoat' },
        { id = 'm_pants_a',   sex = 'male', cat = 'pants',      model = 'CLOTHING_ITEM_M_PANTS_000',      colours = { 1, 2, 3, 4 }, label = 'Work Trousers' },
        { id = 'm_pants_b',   sex = 'male', cat = 'pants',      model = 'CLOTHING_ITEM_M_PANTS_001',      colours = { 1, 2, 3 },    label = 'Canvas Trousers' },
        { id = 'm_pants_c',   sex = 'male', cat = 'pants',      model = 'CLOTHING_ITEM_M_PANTS_002',      colours = { 1, 2, 3 },    label = 'Town Trousers' },
        { id = 'm_boots_a',   sex = 'male', cat = 'boots',      model = 'CLOTHING_ITEM_M_BOOTS_000',      colours = { 1, 2, 3 },    label = 'Work Boots' },
        { id = 'm_boots_b',   sex = 'male', cat = 'boots',      model = 'CLOTHING_ITEM_M_BOOTS_001',      colours = { 1, 2 },       label = 'Riding Boots' },
        { id = 'm_gloves_a',  sex = 'male', cat = 'gloves',     model = 'CLOTHING_ITEM_M_GLOVES_000',     colours = { 1, 2, 3 },    label = 'Work Gloves' },
        { id = 'm_neck_a',    sex = 'male', cat = 'neckwear',   model = 'CLOTHING_ITEM_M_NECKERCHIEF_000', colours = { 1, 2, 3, 4, 5, 6 }, label = 'Neckerchief' },
        { id = 'm_tie_a',     sex = 'male', cat = 'necktie',    model = 'CLOTHING_ITEM_M_NECKTIE_000',    colours = { 1, 2, 3 },    label = 'String Tie' },
        { id = 'm_belt_a',    sex = 'male', cat = 'belt',       m = 4,                                    colours = { 1, 2, 3 },    label = 'Leather Belt' },
        { id = 'm_susp_a',    sex = 'male', cat = 'suspenders', model = 'CLOTHING_ITEM_M_SUSPENDERS_000', colours = { 1, 2, 3 },    label = 'Braces' },
        -- ------------------------------------------------ ladies
        { id = 'f_hat_a',     sex = 'female', cat = 'hat',      model = 'CLOTHING_ITEM_F_HAT_000',        colours = { 1, 2, 3, 4 }, label = 'Felt Hat' },
        { id = 'f_hat_b',     sex = 'female', cat = 'hat',      model = 'CLOTHING_ITEM_F_HAT_001',        colours = { 1, 2, 3 },    label = 'Day Hat' },
        { id = 'f_hat_c',     sex = 'female', cat = 'hat',      model = 'CLOTHING_ITEM_F_HAT_002',        colours = { 1, 2, 3 },    label = 'Town Hat' },
        { id = 'f_shirt_a',   sex = 'female', cat = 'shirt',    model = 'CLOTHING_ITEM_F_SHIRT_000',      colours = { 1, 2, 3, 4 }, label = 'Cotton Blouse' },
        { id = 'f_shirt_b',   sex = 'female', cat = 'shirt',    model = 'CLOTHING_ITEM_F_SHIRT_001',      colours = { 1, 2, 3 },    label = 'Plain Blouse' },
        { id = 'f_chemise_a', sex = 'female', cat = 'shirt',    model = 'CLOTHING_ITEM_F_CHEMISE_000',    colours = { 1, 2, 3 },    label = 'Chemise' },
        { id = 'f_vest_a',    sex = 'female', cat = 'vest',     model = 'CLOTHING_ITEM_F_VEST_000',       colours = { 1, 2, 3 },    label = 'Plain Vest' },
        { id = 'f_coat_a',    sex = 'female', cat = 'coat',     model = 'CLOTHING_ITEM_F_COAT_000',       colours = { 1, 2, 3 },    label = 'Walking Jacket' },
        { id = 'f_ccoat_a',   sex = 'female', cat = 'coat_closed', model = 'CLOTHING_ITEM_F_CLOSECOAT_000', colours = { 1, 2, 3 },  label = 'Buttoned Overcoat' },
        { id = 'f_skirt_a',   sex = 'female', cat = 'skirt',    model = 'CLOTHING_ITEM_F_SKIRT_000',      colours = { 1, 2, 3, 4 }, label = 'Plain Skirt' },
        { id = 'f_skirt_b',   sex = 'female', cat = 'skirt',    model = 'CLOTHING_ITEM_F_SKIRT_001',      colours = { 1, 2, 3 },    label = 'Work Skirt' },
        { id = 'f_skirt_c',   sex = 'female', cat = 'skirt',    model = 'CLOTHING_ITEM_F_SKIRT_002',      colours = { 1, 2, 3 },    label = 'Walking Skirt' },
        { id = 'f_pants_a',   sex = 'female', cat = 'pants',    model = 'CLOTHING_ITEM_F_PANTS_000',      colours = { 1, 2, 3 },    label = 'Riding Trousers' },
        { id = 'f_boots_a',   sex = 'female', cat = 'boots',    model = 'CLOTHING_ITEM_F_BOOTS_000',      colours = { 1, 2, 3 },    label = 'Lace-up Boots' },
        { id = 'f_boots_b',   sex = 'female', cat = 'boots',    model = 'CLOTHING_ITEM_F_BOOTS_001',      colours = { 1, 2 },       label = 'Riding Boots' },
        { id = 'f_gloves_a',  sex = 'female', cat = 'gloves',   model = 'CLOTHING_ITEM_F_GLOVES_000',     colours = { 1, 2, 3 },    label = 'Gloves' },
        { id = 'f_neck_a',    sex = 'female', cat = 'neckwear', model = 'CLOTHING_ITEM_F_NECKERCHIEF_000', colours = { 1, 2, 3, 4, 5, 6 }, label = 'Neckerchief' },
        { id = 'f_tie_a',     sex = 'female', cat = 'necktie',  model = 'CLOTHING_ITEM_F_NECKTIE_000',    colours = { 1, 2, 3 },    label = 'Ribbon Tie' },
        { id = 'f_belt_a',    sex = 'female', cat = 'belt',     m = 4,                                    colours = { 1, 2, 3 },    label = 'Leather Belt' },
    },
}

--[[
    WARDROBE POINTS - open the saved outfit list (no shopping). Every clothes store clerk opens it too.
    Target the spot (MULTItarget, or the key prompt). Positions: the towns' cloakrooms.
]]
Config.Wardrobes = {
    enabled = true,
    radius = 1.2,                  -- MULTItarget sphere size (metres)
    distance = 2.0,                -- how close the player must stand to use it
    serverDistance = 4.0,          -- server check when an outfit is worn from a wardrobe
    blip = false,                  -- show the wardrobe points on the map
    points = {
        vector3(-325.29, 766.24, 117.48),    -- Valentine
        vector3(-1817.11, -368.77, 166.54),  -- Strawberry
        vector3(-825.40, -1323.76, 47.91),   -- Blackwater
        vector3(1331.86, -1377.35, 80.55),   -- Rhodes
        vector3(2550.67, -1159.46, 53.73),   -- Saint Denis
    },
}
