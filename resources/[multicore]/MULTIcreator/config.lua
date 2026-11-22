-- ============================================================
-- MULTIcreator :: config
-- Barber positions are taken from rsg-barbers' config and the creator
-- room from rsg-appearance (RSG v2 framework, GPL v3) - coordinates
-- only, see README credits.
-- ============================================================

Config = {}

Config.Debug = false               -- print extra info to the F8 / server console
Config.DebugReport = false         -- true = the creator reports its state (ped, room, camera) to the server console
Config.Locale = ''                -- language for this script ('' = MULTIcore's language (MULTIConfig.Language), else 'en'); texts are in locales/*.lua

-- ---------------------------------------------------------------
-- Creator room (where a new character is built)
-- ---------------------------------------------------------------
Config.Room = {
    ped = vector4(-558.0, -3781.0, 239.0, 91.0), -- where the ped stands, heading = facing (rsg-appearance creator spot)
    -- the game's character-creator room only exists while these map pieces (imaps) are loaded;
    -- loaded on open, unloaded on close (hashes from RSG v2's rsg-appearance, GPL v3)
    imaps = { 183712523, -1699673416, 1679934574 },
    keepLoaded = true,                           -- true = load the room when the resource starts and keep it (as RSG does)
    light = {                                    -- light on the ped, drawn every frame while open (values from rsg-appearance's creator)
        enabled = true,
        pos = vector3(-560.0, -3781.0, 239.0),   -- where the light hangs (rsg-appearance camloc, in front of the ped); nil = use offset
        offset = vector3(0.0, 2.0, 1.0),         -- only when pos = nil: from the ped, x = right, y = in front, z = up (metres)
        color = { 255, 255, 255 },               -- white
        range = 10.0,                            -- metres
        intensity = 100.0,                       -- brightness (rsg-appearance uses 100.0)
    },
    timecycle = 'Online_Character_Editor',       -- the game's creator screen look (as rsg-appearance); '' = none
    fadeMs = 500,                                -- screen fade time when entering / leaving
}

-- ---------------------------------------------------------------
-- Cameras: one per section. offset is from the ped's centre (about hip height), along the way it faces at open time
--   dist = metres in front, z = height of the camera, lookZ = height it looks at, fov = field of view
-- ---------------------------------------------------------------
Config.Cameras = {
    face = { dist = 0.85, z = 0.65, lookZ = 0.62, side = 0.0, fov = 35.0 },
    body = { dist = 2.6, z = 0.2, lookZ = 0.05, side = 0.0, fov = 40.0 },
    legs = { dist = 1.6, z = -0.45, lookZ = -0.55, side = 0.0, fov = 40.0 },
}
Config.CameraInterpMs = 600        -- camera move time between sections
Config.ZoomStep = 0.1              -- mouse wheel zoom step (metres)
Config.ZoomMin = -0.4              -- closest extra zoom
Config.ZoomMax = 1.2               -- farthest extra zoom
Config.RotateStep = 6.0            -- degrees per key press (A / D or Q / E)
Config.MouseRotateScale = 0.5      -- degrees per pixel when dragging the mouse

-- ---------------------------------------------------------------
-- Look limits and choices
-- ---------------------------------------------------------------
Config.Height = { min = 0.95, max = 1.05, step = 0.01 }  -- must stay inside MULTIConfig.Look MinHeight / MaxHeight
Config.ApplyDelayMs = 120          -- wait this long after the last slider move before the ped is updated
-- builds and waists come from MULTIcore data/appearance.lua (MULTIData.BodySizes / Waists)
Config.BodySliders = true         -- show the Body proportions sliders (arms, chest, waist ... MULTIData.BodyFeatures)
Config.Random = {                 -- the Randomise button
    featureRange = 0.5,            -- face sliders go from -this to +this
    bodyRange = 0.3,               -- body sliders go from -this to +this
    beardChance = 0.5,             -- chance (0..1) of a beard on male characters
}
-- overlays offered in the creator, in menu order (names from MULTIcore data/appearance.lua).
-- These are the ones rsg-appearance uses; acne, complex, disc, grime, foundation, hair and paintedmasks
-- also exist but are untested in game (add them here to offer them).
Config.Overlays = { 'eyebrows', 'scars', 'ageing', 'freckles', 'moles', 'spots', 'beardstabble', 'eyeliners', 'shadows', 'lipsticks', 'blush' }
Config.CancelConfirmMs = 3000      -- Cancel must be pressed twice within this time
Config.OverlayVariants = {         -- how many sheet variants (var) each overlay texture has; others have 1
    lipsticks = 7,                 -- from the data file comment ("7 variants")
    shadows = 6,                   -- from the data file comment ("6 variants")
    eyeliners = 1,                 -- UNVERIFIED: raise if the game has more eyeliner variants
}
-- overlay names shown in the menu come from locales (key overlay_<name>)

-- Clothing shown in the creator (category keys from MULTIcore data/clothes.lua). tint = show palette / tint controls.
-- Categories a sex does not have (skirts on mp_male ...) are left out on their own.
Config.CreatorClothing = {
    { key = 'hats', tint = true },
    { key = 'shirts_full', tint = true },
    { key = 'vests', tint = true },
    { key = 'coats', tint = true },
    { key = 'neckwear', tint = true },
    { key = 'pants', tint = true },
    { key = 'skirts', tint = true },
    { key = 'dresses', tint = true },
    { key = 'boots', tint = true },
    { key = 'gloves', tint = false },
}

-- Starting clothes of a new look (index into the category, see data/clothes.lua). Players can change them.
Config.StartingClothes = {
    male = { shirts_full = 1, pants = 1, boots = 1 },
    female = { shirts_full = 1, pants = 1, boots = 1 },
}

-- Identity form
Config.Identity = {
    minAge = 18,                   -- youngest age allowed
    maxAge = 80,                   -- oldest age allowed
    gameYear = 1899,               -- the age is worked out from the birth date against this year
    nationalities = { 'american', 'mexican', 'english', 'irish', 'scottish', 'german', 'french', 'italian', 'swedish', 'norwegian', 'chinese', 'native', 'other' }, -- choices; text from locales (nation_<key>)
    descriptionMax = 500,          -- longest description (characters)
    nicknameMax = 40,              -- longest nickname (characters)
}

-- ---------------------------------------------------------------
-- Barber
-- ---------------------------------------------------------------
Config.Barber = {
    price = 5,                     -- cash taken when the player saves a new style (0 = free)
    interact = 'auto',             -- 'auto' = MULTItarget when it runs (else hold-key prompt), 'target' = MULTItarget, 'prompt' = hold-key prompt
    promptKey = 0xCEFD9220,        -- INPUT_ENTER (E), see redm-info Controls.cs
    promptDistance = 2.0,          -- how close (metres) to the barber the prompt shows (prompt mode)
    targetRadius = 1.5,            -- MULTItarget sphere size (metres)
    targetDistance = 2.0,          -- how close (metres) the player must stand to use the MULTItarget option
    targetIcon = 'fas fa-scissors', -- MULTItarget icon (Font Awesome)
    movePlayer = false,            -- true = put the player on the shop's seat spot while the barber works
    npcModel = `s_m_m_barber_01`,  -- barber shopkeeper (redm-info PedHash: SmmBarber01 0xD2FA5F10)
    npcDistance = 30.0,            -- spawn the barber NPC when the player is this close (metres)
    npcCheckMs = 1000,             -- how often (ms) the NPC distance is checked
    npcZOffset = -1.0,             -- NPC height correction (shop z is about 1 m above the floor)
    useRange = 4.0,                -- server check: how close to a barber the player must be to pay
    requireShop = true,            -- false = Open('barber') from other scripts may charge anywhere
    refundWindowSec = 60,          -- if saving fails right after paying, the money comes back within this time
    blips = true,                  -- show barber blips (per shop: blip = true)
    blipStyle = 1664425300,        -- blip style used by rsg-barbers -- UNVERIFIED (not in femga natives.json)
    blipSprite = -2090472724,      -- barber sprite used by rsg-barbers -- UNVERIFIED
    blipScale = 0.2,               -- blip size
    -- blip name: locale key blip_barber
    -- overlays the barber may change (hair, beard and the rest are always allowed)
    overlays = { 'eyebrows', 'beardstabble', 'eyeliners', 'lipsticks', 'shadows', 'blush' }, -- must also be in Config.Overlays
    light = { color = { 255, 236, 205 }, range = 6.0, intensity = 3.0 }, -- light drawn at the shop's light spot while the barber works
}

-- Barber shops (coordinates from rsg-barbers' config, RSG v2 framework, GPL v3)
Config.BarberShops = {
    {
        id = 'valentine',  -- shop id; its name is locale key shop_valentine
        coords = vector3(-307.96, 814.16, 118.99),       -- prompt / target point and NPC position
        npc = vector4(-307.96, 814.16, 118.99, 190.93),
        seat = vector4(-306.62, 813.56, 118.75, 90.60),  -- used when movePlayer = true
        light = vector3(-307.39, 813.43, 119.51),      -- light drawn while the barber works
        blip = true,                                      -- show this shop on the map
    },
    {
        id = 'saintdenis',  -- shop id; its name is locale key shop_saintdenis
        coords = vector3(2656.16, -1180.87, 53.28),
        npc = vector4(2656.16, -1180.87, 53.28, 176.33),
        seat = vector4(2655.38, -1180.92, 53.00, 182.8),
        light = vector3(2655.35, -1182.23, 54.07),
        blip = true,
    },
    {
        id = 'blackwater',  -- shop id; its name is locale key shop_blackwater
        coords = vector3(-815.88, -1364.72, 43.75),
        npc = vector4(-815.88, -1364.72, 43.75, 268.01),
        seat = vector4(-815.17, -1368.75, 43.50, 95.5),
        light = vector3(-816.46, -1368.77, 44.26),
        blip = true,
    },
}


-- ---------------------------------------------------------------
-- Timings (milliseconds)
-- ---------------------------------------------------------------
Config.Timing = {
    collisionWaitMs = 5000,        -- longest wait for the creator room's ground to load
    settleMs = 1500,               -- longest wait for the ped to settle onto the creator room floor
    barberFadeMs = 300,            -- screen fade when moving to / from the barber seat
    fadeGraceMs = 1000,            -- extra wait for a screen fade to finish before going on
    notifyMs = 5000,               -- how long notifications stay
}
