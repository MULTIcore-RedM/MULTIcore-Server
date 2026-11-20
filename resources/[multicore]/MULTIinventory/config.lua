-- ============================================================
-- MULTIinventory settings. Every option has its default in the comment.
-- Sections: engine (server), UI (client), weapons and ammo (both), VORP face.
-- ============================================================
Config = Config or {}

-- Language for this script ('' = use server.cfg `setr multicore_locale`, else 'en').
Config.Locale = ''                       -- default ''

-- Print extra lines to the server console (moves, loads, saves).
Config.Debug = false                     -- default false
Config.DebugUse = false                  -- true = every item use (and why it stopped) is printed to the server console

------------------------------------------------------------------
-- Sizes (server)
------------------------------------------------------------------
-- The player's satchel takes its size from the character (players.slots / players.weight,
-- RSG's PlayerDefaults: 25 slots / 35000 g). These are used only if those are missing.
Config.Player = {
    Slots = 25,                          -- default 25
    MaxWeight = 35000,                   -- default 35000 (grams)
    MaxCount = nil,                      -- default nil (no limit on the total item count)
    UseItemLimits = true,                -- default true  (VORP per-item `limit` applies to the satchel)
}

-- A stash opened without its own size.
Config.Stash = {
    Slots = 100,                         -- default 100
    MaxWeight = 2000000,                 -- default 2000000 (grams)
}

-- Items dropped on the ground (memory only, gone after a restart). The client's look is Config.Drops below.
Config.Drop = {
    Slots = 50,                          -- default 50
    MaxWeight = 1000000,                 -- default 1000000
    ExpireMinutes = 15,                  -- default 15 (an unopened drop is removed after this)
    Model = 'p_bag01x',                  -- default 'p_bag01x' (from RSG's config)
}

------------------------------------------------------------------
-- Rules (server)
------------------------------------------------------------------
Config.MaxDistance = 5.0                 -- default 5.0 (metres to a stash / drop / searched player while moving items)
Config.GiveDistance = 3.0                -- default 3.0 (metres between giver and receiver, checked on the server)
Config.RateLimitMs = 100                 -- default 100 (one move / use / give per player per this many ms)
Config.AutoSaveSeconds = 60              -- default 60 (changed satchels and stashes are written this often)
Config.ForceDropWhenFull = true          -- default true  (RSG AddItem on a full satchel puts the item on the ground)
Config.AdminAce = 'command'              -- default 'command' (ACE that skips distance checks)

-- Item decay (RSG items with `decay = minutes` lose quality). Off by default.
Config.Decay = {
    Enabled = false,                     -- default false
    WhileOffline = false,                -- default false (also decays while the character is logged out)
}

-- Stash names that need a job or gang (RSG's restricted prefixes). Prefix -> rule.
--   jobs = list of job names, gang = true (stash 'gang-<gangname>-...'), admin = true
Config.RestrictedStashes = {
    ['police-']   = { jobs = { 'police', 'marshal', 'sheriff' } },
    ['marshal-']  = { jobs = { 'police', 'marshal', 'sheriff' } },
    ['evidence-'] = { jobs = { 'police', 'marshal', 'sheriff' } },
    ['gang-']     = { gang = true },
    ['admin-']    = { admin = true },
}

-- Inventory ids a player's client may never ask to open; only a server script opens them.
Config.ServerOpenOnly = {
    'custom:safedeposit:',               -- default (MULTIbank's safe-deposit boxes)
    'custom:camp:',                      -- default (MULTIcamps' camp chests)
    'custom:horse_',                     -- default (MULTIhorses' saddlebags)
    'stash:multilaw_evidence_',          -- default (MULTIlaw's evidence lockers; MULTIlaw Config.Evidence.Prefix)
    'stash:multilaw_jailitems_',         -- default (items kept while in a cell or Sisika; MULTIlaw Config.Jail.ItemStashPrefix)
    'stash:lawstorage',                  -- default (rsg-lawman's law storage; MULTIlaw Config.Compat.StoragePrefix)
    -- wagon storage: MULTIwagons, rsg-wagons and every RSG v2 / RINGO trunk script open it from
    -- the server (a server event or callback after their own checks), never from the client
    'trunk:',                            -- default (MULTIwagons' wagon storage)
}

------------------------------------------------------------------
-- Trading between two players (server + client)
------------------------------------------------------------------
Config.Trade = {
    Enabled = true,                      -- default true
    Command = 'trade',                   -- default 'trade' (/trade = nearest player, /trade <server id> = that player)
    UseTarget = true,                    -- default true  ("Offer a trade" on players through MULTItarget when it runs; waits for it at start, reach 2.5 m at most)
    TargetIcon = 'fas fa-handshake',     -- default 'fas fa-handshake'
    SatchelButton = true,                -- default true  (a Trade button on the satchel page)
    Distance = 3.0,                      -- default 3.0 (metres to offer a trade; checked on the server)
    KeepDistance = 6.0,                  -- default 6.0 (walking further apart cancels; also checked at the swap)
    RequestSeconds = 20,                 -- default 20 (an unanswered request runs out after this)
    MaxItems = 12,                       -- default 12 (item stacks each player may offer)
    MaxCash = 10000,                     -- default 10000 (most cash one player may offer, dollars; cents allowed)
    AcceptDelayMs = 1500,                -- default 1500 (after any change, Accept works again only after this; stops last-second swaps)
    CheckMs = 1000,                      -- default 1000 (how often walking away / death / leaving is checked)
}

-- Item registry
Config.VorpItems = {
    Enabled = true,                      -- default true  (also read the VORP `items` table when it exists)
    WeightUnit = 'kg',                   -- default 'kg'  ('kg' = VORP weights are kilograms, 'g' = grams)
    RefreshMinutes = 5,                  -- default 5 (re-read the table this often; unknown names are also looked up at once; 0 = never)
}

------------------------------------------------------------------
-- Stores are not part of the inventory: they are their own resource, MULTIstores.
-- RSG scripts that call exports['rsg-inventory']:CreateShop / OpenShop / DoesShopExist /
-- RestockShop are passed on to MULTIstores (start it after MULTIinventory).
------------------------------------------------------------------

------------------------------------------------------------------
-- UI (client)
------------------------------------------------------------------
Config.ImagePaths = {}                   -- default {} (nui:// item image folders tried in order, then a plain icon; none shipped;
                                         --             MULTIstores reads these too through exports.MULTIinventory:GetImagePaths())
Config.OpenKey = 0x4CC0E2FE              -- default 0x4CC0E2FE (B)
Config.OpenCommand = 'inventory'         -- default 'inventory'
Config.CloseCommand = 'closeinv'         -- default 'closeinv'
Config.UseCooldown = 500                 -- default 500 (ms between uses)
Config.CloseOnUse = true                 -- default true  (the page closes when an item is used)
Config.CloseOnWeaponUse = false          -- default false (the page stays open when a weapon is equipped)
Config.RefreshDelay = 1500               -- default 1500 (ms after login before the satchel is asked for)

Config.Hotbar = {
    Enabled = true,                      -- default true
    Size = 5,                            -- default 5 (first slots of the satchel)
    Keys = { 0xE6F612E4, 0x1CE6D9EB, 0x4F49CC4C, 0x8F9F9E58, 0xAB62E997 }, -- default 1-5
    ToggleKey = 0x26E9DC00,              -- default 0x26E9DC00 (Z)
    ShowTime = 2500,                     -- default 2500 (ms the hotbar stays up)
    Command = 'hotbar',                  -- default 'hotbar'
}

Config.ItemBox = {
    Enabled = true,                      -- default true  (item pop-ups)
    Time = 3500,                         -- default 3500 (ms each pop-up shows)
    Max = 5,                             -- default 5 (pop-ups on screen at once)
}

Config.Give = {
    Enabled = true,                      -- default true
    Distance = 3.0,                      -- default 3.0 (client-side search radius; the server checks Config.GiveDistance)
    AnimDict = 'mech_butcher',           -- default 'mech_butcher'
    AnimName = 'small_fish_give_player', -- default 'small_fish_give_player'
}

Config.Drops = {
    Enabled = true,                      -- default true
    Model = 'p_bag01x',                  -- default 'p_bag01x' (bag prop the client draws)
    UseTarget = true,                    -- default true  (MULTItarget "Open" on the bag when MULTItarget runs, else a key prompt; false = always the key prompt)
    PromptKey = 0xCEFD9220,              -- default 0xCEFD9220 (E)
    TargetIcon = 'fas fa-box-open',      -- default 'fas fa-box-open'
    OpenDistance = 2.0,                  -- default 2.0
    DrawDistance = 40.0,                 -- default 40.0
    NotOnMount = true,                   -- default true  (no opening from horseback)
}

------------------------------------------------------------------
-- Weapons (server + client)
------------------------------------------------------------------
Config.Weapons = {
    -- server
    Handler = 'auto',                    -- default 'auto' ('auto' = rsg-weapons when it runs, else MULTIinventory's client; 'rsg' / 'multi' to force)
    DefaultQuality = 100,                -- default 100
    RegisterSerials = true,              -- default true (write used weapons' serials to player_weapons when that table exists)
    -- client
    Enabled = true,                      -- default true
    Components = true,                   -- default true  (apply info.components / componentshash)
    ComponentsDelay = 500,               -- default 500 (ms the client waits for the satchel update before re-applying components)
    TwoSlots = true,                     -- default true  (two pistols / revolvers at once)
    BrokenQuality = 0,                   -- default 0 (at or below this quality a weapon will not fire)
    AmmoCheckInterval = 250,             -- default 250 (ms)
    SyncInterval = 2000,                 -- default 2000 (ms between loaded-ammo reports to the server)
    AfterRespawn = 'medic',              -- default 'medic'
    RespawnDelay = 1500,                 -- default 1500 (ms)
}

------------------------------------------------------------------
-- Ammo (server + client)
-- Rounds are counted on the server: every ammo type has a one-round item (ammo_revolver,
-- ammo_arrow_single ...; def.ammoPer = 1). Boxes and arrow bundles (def.ammoPer = rounds)
-- turn into rounds as soon as they reach a satchel, so a half-used box is never lost.
------------------------------------------------------------------
Config.Ammo = {
    -- server
    RoundWeight = 5,                     -- default 5 (grams per generated round item)
    BoxesToRounds = true,                -- default true (open boxes / bundles into rounds in the satchel; off by itself when rsg-ammo runs)
    -- box or bundle item -> { ammo type, rounds } (rounds from rsg-ammo's refill values)
    Boxes = {
        ammo_box_revolver                    = { 'AMMO_REVOLVER', 12 },
        ammo_box_revolver_express            = { 'AMMO_REVOLVER_EXPRESS', 12 },
        ammo_box_revolver_explosive          = { 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', 10 },
        ammo_box_revolver_velocity           = { 'AMMO_REVOLVER_HIGH_VELOCITY', 12 },
        ammo_box_revolver_splitpoint         = { 'AMMO_REVOLVER_SPLIT_POINT', 12 },
        ammo_box_pistol                      = { 'AMMO_PISTOL', 12 },
        ammo_box_pistol_express              = { 'AMMO_PISTOL_EXPRESS', 12 },
        ammo_box_pistol_explosive            = { 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', 10 },
        ammo_box_pistol_velocity             = { 'AMMO_PISTOL_HIGH_VELOCITY', 12 },
        ammo_box_pistol_splitpoint           = { 'AMMO_PISTOL_SPLIT_POINT', 12 },
        ammo_box_repeater                    = { 'AMMO_REPEATER', 12 },
        ammo_box_repeater_express            = { 'AMMO_REPEATER_EXPRESS', 12 },
        ammo_box_repeater_explosive          = { 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', 10 },
        ammo_box_repeater_velocity           = { 'AMMO_REPEATER_HIGH_VELOCITY', 12 },
        ammo_box_repeater_splitpoint         = { 'AMMO_REPEATER_SPLIT_POINT', 12 },
        ammo_box_rifle                       = { 'AMMO_RIFLE', 12 },
        ammo_box_rifle_express               = { 'AMMO_RIFLE_EXPRESS', 12 },
        ammo_box_rifle_explosive             = { 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', 10 },
        ammo_box_rifle_velocity              = { 'AMMO_RIFLE_HIGH_VELOCITY', 12 },
        ammo_box_rifle_splitpoint            = { 'AMMO_RIFLE_SPLIT_POINT', 12 },
        ammo_box_rifle_elephant              = { 'AMMO_RIFLE_ELEPHANT', 10 },
        ammo_box_shotgun                     = { 'AMMO_SHOTGUN', 12 },
        ammo_box_shotgun_buckshot_incendiary = { 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', 7 },
        ammo_box_shotgun_slug                = { 'AMMO_SHOTGUN_SLUG', 12 },
        ammo_box_shotgun_slug_explosive      = { 'AMMO_SHOTGUN_SLUG_EXPLOSIVE', 10 },
        ammo_box_varmint                     = { 'AMMO_22', 12 },
        ammo_box_varmint_tranquilizer        = { 'AMMO_22_TRANQUILIZER', 12 },
        -- RSG's arrow items are bundles (rsg-ammo gives `refill` arrows per item)
        ammo_arrow                           = { 'AMMO_ARROW', 10 },
        ammo_arrow_small                     = { 'AMMO_ARROW_SMALL_GAME', 10 },
        ammo_arrow_fire                      = { 'AMMO_ARROW_FIRE', 3 },
        ammo_arrow_poison                    = { 'AMMO_ARROW_POISON', 2 },
        ammo_arrow_dynamite                  = { 'AMMO_ARROW_DYNAMITE', 1 },
    },
    -- client
    Items = {},                          -- default {} (extra item -> 'AMMO_*' type, for items the client does not know)
    PerItem = {},                        -- default {} (item -> rounds, overrides def.ammoPer)
    BoxRounds = 12,                      -- default 12 (rounds of an ammo_box_* item without def.ammoPer)
    UseLoads = true,                     -- default true  (using an ammo item loads it into the gun)
    BlockWorldAmmo = true,               -- default true  (ammo picked up in the world is not kept)
}

------------------------------------------------------------------
-- VORP face (server/vorp, client/vorp)
------------------------------------------------------------------
Config.Vorp = {
    Debug = false,                       -- default false (VORP face console lines)
    UseInvCapacity = true,               -- default true  (metadata.vorp.invCapacity limits the satchel's item count, weapons and ammo not counted)
    SyncCapacityToEngine = false,        -- default false (write VORP capacity changes into the satchel's size)
    HiddenInfoKeys = { 'quality', 'lastUpdate' }, -- default { 'quality', 'lastUpdate' } (info keys VORP scripts do not see as metadata)
    AmmoItems = {},                      -- default {} (extra VORP ammo item -> 'AMMO_*' type)
    AmmoMax = nil,                       -- default nil (cap on rounds per ammo type; nil = the game data max)
    MaxWeapons = 0,                      -- default 0 (most weapons a character may carry; 0 = no limit)
    WeaponCheckDefault = 'weapon_revolver_cattleman', -- default 'weapon_revolver_cattleman'
    CustomInventorySlots = 50,           -- default 50 (slots of a VORP custom inventory made without a size)
    CustomInventoryMaxWeight = 1000000000, -- default 1000000000 (VORP custom inventories count items, not weight)
}

------------------------------------------------------------------
-- UI builder: further client keys go here.
------------------------------------------------------------------
Config.UI = Config.UI or {}
