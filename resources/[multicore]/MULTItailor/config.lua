Config = Config or {}

--[[
    MULTItailor - general settings.
      config.lua            this file: core settings, MULTIcore look, wardrobe toggles, outfits
      config/tailor.lua     the tailor job: clothing categories, materials, sewing, counter, till
      config/locations.lua  tailor shops placed in config
      config/stores.lua     public clothes stores (NPC clerk), their stock, wardrobe points
    Texts: locales/<lang>.json (10 languages).

    MULTItailor is MULTIcore's clothing system. Every garment is an inventory item: what a character
    wears sits in MULTIinventory's equipment slots, and MULTItailor keeps MULTIcore's saved look in step
    with those slots (server/90_look.lua).
]]

Config.Debug = false

-- MULTIcore answers as both rsg-core and vorp_core; MULTItailor always talks to it through its RSG face
-- and hands every garment over as a MULTIinventory clothing item. Leave these two as they are.
Config.Framework = 'rsg'
Config.Inventory = 'multi'

-- Language: '' = the server's  setr multicore_locale  (every MULTI script at once), else 'en', 'de' ...
Config.Locale = ''

-- Interaction: 'auto' = MULTItarget when it runs, else a hold-key prompt. 'ox' | 'prompt' to force one.
Config.Target = 'auto'

-- Notifications: 'auto' = MULTIcore's notifications when MULTIcore runs, else ox_lib.
Config.Notify = 'auto'

-- Admin access: ACE (add_ace group.admin multitailor.admin allow) or one of these framework groups.
Config.Admin = {
    ace = 'multitailor.admin',
    groups = { 'admin', 'superadmin', 'god' },
}

-- What a garment becomes in the inventory: always a MULTIinventory clothing item (clothing_hat, clothing_shirt ...)
-- or an outfit bundle (clothing_outfit). `tailored_outfit` is only read: an old one turns into a bundle when used.
Config.Items = {
    format = 'multi',
    outfitItem = 'tailored_outfit',
    inventoryResource = 'MULTIinventory',
}

-- ---------------------------------------------------------------- MULTIcore look
-- The worn clothing is copied into the character's MULTIcore look after every change, so the
-- character select screen, the barber and every look reload show the same clothes.
Config.Look = {
    mirror = true,             -- copy the worn pieces into the MULTIcore look
    debounceMs = 800,          -- wait this long after the last change before saving (several changes = one save)
    -- First time a character loads with no clothing items but clothes in their MULTIcore look (a character
    -- made before MULTItailor ran, or straight from the creator): those clothes become items in their
    -- equipment slots, once. Nobody turns up naked.
    importOnFirstLoad = true,
    importDelayMs = 4000,      -- wait after the inventory has loaded the character before looking
    reapplyDelayMs = 600,      -- after MULTIcore puts the saved look back on, put the worn items on again after this
}

-- ---------------------------------------------------------------- quick toggles (also rsg-wardrobe calls)
-- A toggle takes a worn piece off for the moment (it stays in its equipment slot) and puts it back.
-- Other scripts use the same through rsg-wardrobe's exports and events (MULTItailor answers as rsg-wardrobe).
Config.Toggles = {
    enabled = true,
    command = 'clothes',       -- opens the toggle menu ('' = no command)
    -- id = locale key 'toggle_<id>', icon = Font Awesome name, keys = equipment slots switched together
    items = {
        { id = 'hat',      icon = 'hat-cowboy',   keys = { 'Hat' } },
        { id = 'mask',     icon = 'mask',         keys = { 'Mask' } },
        { id = 'coat',     icon = 'vest',         keys = { 'Coat', 'CoatClosed', 'Poncho', 'Cloak' } },
        { id = 'vest',     icon = 'vest-patches', keys = { 'Vest' } },
        { id = 'gloves',   icon = 'mitten',       keys = { 'Glove', 'Gauntlets' } },
        { id = 'neckwear', icon = 'user-tie',     keys = { 'NeckWear', 'NeckTies' } },
        { id = 'eyewear',  icon = 'glasses',      keys = { 'EyeWear' } },
        { id = 'gunbelt',  icon = 'gun',          keys = { 'Gunbelt', 'Holster', 'GunbeltAccs' } },
        { id = 'satchel',  icon = 'bag-shopping', keys = { 'Satchels' } },
    },
}

-- ---------------------------------------------------------------- saved outfits
-- An outfit is a named list of the clothing items you wear now. Wearing it puts on the pieces you still
-- own (in your satchel or worn); nothing is created. Outfits open at every clothes store and wardrobe point.
Config.Outfits = {
    command = '',              -- '' = outfits are changed only at a clothes store, a wardrobe point or another script's
                               -- wardrobe (a house ...). A command name here (e.g. 'outfits') opens the list anywhere.
    passSeconds = 600,         -- another script's wardrobe (a house ...) lets the player change outfits for this long ...
    passDistance = 5.0,        -- ... while they stay within this many metres of where they opened it
    clientPass = true,         -- false = only server-side calls (exports.MULTItailor:GrantWardrobe / OpenOutfits,
                               -- vorp_character's OpenOutfitsMenu) open such a wardrobe, not rsg-appearance's client event
    nameMax = 40,
    undress = false,           -- true = wearing an outfit also takes off worn pieces that are not part of it
}

-- Licences (optional). A licence office resource that has a CanUseJobFeature export can require a valid
-- tailor licence for counter sales. Nothing changes when it is not installed.
Config.Licence = {
    enabled = true,
    resource = 'RINGOjobsandcrafting',
    businessId = 'tailor',
    requireFor = { counterSales = true, crafting = false, boss = false },
    failOpen = true,   -- licence office not running -> allow
}

-- NPC clothing (optional). Only when an NPC clothing resource with the same API runs (RINGOnpcclothing);
-- otherwise this section of the Outfit Designer does not show. Tailors search the confirmed NPC pieces,
-- preview them on the dummy, name and cut them:
--   * a single garment  -> one `npc_garment` item
--   * an outfit (minOutfitPieces .. maxOutfitPieces) -> one `npc_outfit` item; using it unpacks it
Config.NpcClothing = {
    enabled = true,
    resource = 'RINGOnpcclothing',
    garmentItem = 'npc_garment',
    outfitItem = 'npc_outfit',
    minOutfitPieces = 3,
    maxOutfitPieces = 14,
    pieceNameMax = 40,
    -- materials per piece, by NPC clothing category id (default for anything not listed)
    materials = {
        default  = { { item = 'cloth', amount = 2 }, { item = 'brass_button', amount = 1 } },
        hats     = { { item = 'wool', amount = 2 }, { item = 'leather', amount = 1 } },
        coats    = { { item = 'fabric', amount = 4 }, { item = 'wool', amount = 2 }, { item = 'brass_button', amount = 4 } },
        pants    = { { item = 'fabric', amount = 3 }, { item = 'brass_button', amount = 2 } },
        chaps    = { { item = 'leather', amount = 3 }, { item = 'twine', amount = 1 } },
        boots    = { { item = 'leather', amount = 3 }, { item = 'twine', amount = 1 } },
        belts    = { { item = 'leather', amount = 2 }, { item = 'brass_button', amount = 1 } },
        gunbelts = { { item = 'leather', amount = 3 }, { item = 'brass_button', amount = 2 } },
        doublegunbelts = { { item = 'leather', amount = 5 }, { item = 'brass_button', amount = 3 } },
        bandages = { { item = 'cloth', amount = 1 } },
        holsters = { { item = 'leather', amount = 2 } },
        offhand  = { { item = 'leather', amount = 2 } },
        satchels = { { item = 'leather', amount = 2 }, { item = 'twine', amount = 1 } },
    },
    -- the camera view the dummy turns to when a piece of this NPC clothing category is previewed
    views = {
        hats = 'head', masks = 'head', neckwear = 'head', badges = 'torso',
        coats = 'torso', shirts = 'torso', vests = 'torso', gloves = 'torso', belts = 'torso', gunbelts = 'torso',
        doublegunbelts = 'torso', bandages = 'full', holsters = 'torso',
        offhand = 'torso', weaponcarry = 'torso', satchels = 'torso',
        pants = 'legs', chaps = 'legs', boots = 'legs',
    },
}

-- Money: cash. Prices are dollars with cents.
Config.Currency = { id = 0, symbol = '$' }

-- Server-side rate limits (per player): count calls inside window ms.
Config.RateLimits = {
    default = { count = 8, window = 4000 },
    buy     = { count = 4, window = 3000 },
    cut     = { count = 2, window = 4000 },
    preview = { count = 14, window = 3000 },   -- NPC piece previews at the designer
    admin   = { count = 10, window = 5000 },
    outfit  = { count = 6, window = 4000 },
}

-- Placement from other resources: MULTItailor has a dynamic-location API (server/10_points.lua), so a
-- job placement tool can add cutting tables, counters, offices and stockrooms live.
Config.DynamicLocations = { enabled = true, max = 300 }
