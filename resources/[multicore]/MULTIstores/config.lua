-- ============================================================
-- MULTIstores settings (part of MULTIcore, GPL v3)
-- The store list is in config/stores.lua, what each store sells and buys
-- in config/products.lua, weapon and ammo prices in config/gunsmith.lua.
-- Prices are dollars with cents, at 1899 level (RDR2 store prices where known,
-- else historical late-1890s prices; the old economy SPEC is no longer used).
-- A store never pays more than half of the lowest price
-- the same item is sold for anywhere (no money loops). A warning is printed
-- at start when a store breaks that rule.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = setr multicore_locale, else English)
Config.Debug = false                -- default false (prints every purchase and sale to the server console)

---------------------------------
-- money
---------------------------------
Config.Currency = 'cash'            -- default 'cash' (MULTIcore money type players pay with and are paid in)
Config.CurrencySign = '$'           -- default '$' (money sign on the store screen)
Config.MaxPerPurchase = 100         -- default 100 (most of one item bought or sold at once)

---------------------------------
-- how players open a store
---------------------------------
Config.Interact = 'auto'            -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target' = MULTItarget on the counter and clerk; 'prompt' = hold-key prompt)
Config.PromptKey = 'J'              -- default 'J' (key name from MULTIcore's shared/keybinds.lua; prompt mode only)
Config.PromptDistance = 2.5         -- default 2.5 (metres from the clerk spot at which the prompt shows; prompt mode only)
Config.TargetIcon = 'fas fa-store'  -- default 'fas fa-store' (MULTItarget icon; target mode only)
Config.TargetRadius = 1.2           -- default 1.2 (size of the MULTItarget sphere on the counter; target mode only)
Config.TargetDistance = 2.5         -- default 2.5 (how close the player must stand to use the target; target mode only)

-- The server re-checks every purchase and sale: the player must stand this close
-- to the store's counter (needs OneSync, which MULTIcore servers run).
Config.ServerDistanceCheck = true   -- default true (false only when OneSync is off)
Config.MaxUseDistance = 6.0         -- default 6.0 (metres from the counter; a store may set its own `distance`)
Config.CheckIntervalMs = 1000       -- default 1000 (ms between client checks: clerks near, walked away from an open store)

---------------------------------
-- stock
---------------------------------
Config.PersistStock = true          -- default true (stock of the stores in config/stores.lua survives a restart)
-- Some items (tent, lockpick, cloth, goldpan ...) are registered by other MULTI resources
-- a moment after start. A config store item that is not in the registry yet is added
-- as soon as it appears; only one still missing after this wait is skipped with a warning.
Config.LateItemSeconds = 60         -- default 60 (seconds to wait for items other resources register at start)
Config.Restock = {
    Minutes = 60,                   -- default 60 (every this many minutes each item gains `restock` back, or is filled up; 0 = never)
    CheckEverySeconds = 60,         -- default 60 (how often the restock timer is looked at)
}

---------------------------------
-- selling to a store
---------------------------------
Config.Sell = {
    Enabled = true,                 -- default true (false = no Sell tab anywhere)
    QualityScales = true,           -- default true (an item with info.quality pays price x quality / 100)
}

---------------------------------
-- opening hours (in-game clock)
---------------------------------
-- The game clock lives on the client, so hours are checked when a store is opened
-- (the server cannot read the game time). A store may set its own `hours = { open = 6, close = 22 }`
-- or `hours = false` (always open).
Config.Hours = {
    Enabled = false,                -- default false (stores are always open)
    Open = 7,                       -- default 7 (opening hour, 24 h clock)
    Close = 21,                     -- default 21 (closing hour; the store shuts at Close:00)
}

---------------------------------
-- clerks
---------------------------------
Config.Npc = {
    Enabled = true,                 -- default true (a clerk stands at every store that has an `npc` spot)
    SpawnDistance = 30.0,           -- default 30.0 (clerk is made when the player is this close, removed beyond it)
    ZOffset = -1.0,                 -- default -1.0 (added to the clerk z so he stands on the floor)
    LoadTimeoutMs = 5000,           -- default 5000 (give up loading a clerk model after this long)
    Scenarios = true,               -- default true (clerks play their store type's scenario, e.g. writing in a notebook)
}

---------------------------------
-- blips
---------------------------------
Config.Blips = {
    Enabled = true,                 -- default true
    Style = 1664425300,             -- default 1664425300 (BlipAddForCoords style; the value RSG v2 scripts use) -- UNVERIFIED locally
    Scale = 0.2,                    -- default 0.2
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 8,                      -- default 8 (at most this many store actions ...)
    WindowMs = 3000,                -- default 3000 (... in this many ms, per player)
}

---------------------------------
-- item pictures
---------------------------------
Config.ImagePaths = nil             -- default nil (nil = use MULTIinventory's Config.ImagePaths; or a list of nui:// folders)

---------------------------------
-- store types
---------------------------------
-- label:    locale key of the type name ('%s General Store' gets the town name)
-- products: list name in config/products.lua ('gunsmith' is built from MULTIinventory's weapon data)
-- model:    default clerk model (checked against femga peds_list.lua); a store may set its own `model`
-- scenario: what the clerk does (redm-info Scenarios.lua)
-- blip:     blip texture name (names RSG v2 scripts use, see README)
-- enabled:  false hides every store of this type (e.g. turn butchers off when rsg-hunting runs its own)
Config.Types = {
    general  = { label = 'type_general',  products = 'general',  model = 's_m_m_unibutchers_01', scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',        blip = 'blip_shop_store',          enabled = true },
    gunsmith = { label = 'type_gunsmith', products = 'gunsmith', model = 's_m_m_unibutchers_01', scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',        blip = 'blip_shop_gunsmith',       enabled = true },
    butcher  = { label = 'type_butcher',  products = 'butcher',  model = 's_m_m_unibutchers_01', scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',        blip = 'blip_shop_animal_trapper', enabled = true },
    trapper  = { label = 'type_trapper',  products = 'trapper',  model = 'u_m_m_sdtrapper_01',   scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',        blip = 'blip_shop_animal_trapper', enabled = true },
    doctor   = { label = 'type_doctor',   products = 'doctor',   model = 'u_m_m_valdoctor_01',   scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK',        blip = 'blip_shop_doctor',         enabled = true },
    saloon   = { label = 'type_saloon',   products = 'saloon',   model = 'u_m_o_blwbartender_01', scenario = 'WORLD_HUMAN_BARTENDER_CLEAN_GLASS', blip = 'blip_saloon',              enabled = true },
}

---------------------------------
-- rsg-shops compatibility
---------------------------------
-- MULTIstores answers as rsg-shops. RSG scripts open stores with
--   TriggerServerEvent('rsg-shops:server:openstore', products, name, label)
-- `name` is a store in config/stores.lua (same names as rsg-shops: gen-valentine, wep-rhodes ...),
-- or one of the lists below (rsg-lawman opens 'armoury', rsg-prison 'prison').
Config.RsgShops = {
    Enabled = true,                 -- default true
    -- product lists that only scripts open (no counter in the world, so no distance check, like rsg-shops)
    Products = {
        armoury = {                 -- law armoury: free issue, law only (rsg-shops' list)
            { name = 'weapon_revolver_cattleman',  amount = 5,  price = 0 },
            { name = 'weapon_repeater_winchester', amount = 5,  price = 0 },
            { name = 'ammo_box_revolver',          amount = 50, price = 0 },
            { name = 'ammo_box_repeater',          amount = 50, price = 0 },
        },
        prison = {                  -- prison commissary
            { name = 'bread', amount = 50, price = 0.10 },
            { name = 'water', amount = 50, price = 0.05 },
        },
        medic = {                   -- doctors' supply cupboard: free issue, medics only
            { name = 'bandage',      amount = 50, price = 0 },
            { name = 'fieldbandage', amount = 50, price = 0 },
            { name = 'firstaid',     amount = 50, price = 0 },
        },
    },
    -- who may open which list (job type from MULTIcore's shared/jobs.lua), like rsg-shops
    JobTypes = {
        armoury = 'leo',
        medic = 'medic',
    },
}
