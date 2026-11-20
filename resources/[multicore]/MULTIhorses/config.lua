-- ============================================================
-- MULTIhorses settings (part of MULTIcore, GPL v3)
-- Stables are in config/stables.lua, the horses for sale in
-- config/horses.lua, saddles and blankets in config/tack.lua.
-- Prices are dollars with cents at 1899 level (RDR2's stable prices).
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = setr multicore_locale, else English)
Config.Debug = false                -- default false (prints purchases, sales, deaths and refused actions to the server console)

---------------------------------
-- money and limits
---------------------------------
Config.Currency = 'cash'            -- default 'cash' (MULTIcore money type players pay with and are paid in)
Config.CurrencySign = '$'           -- default '$' (money sign in the menus)
Config.MaxHorses = 3                -- default 3 (most horses one character may own)
Config.SellBack = 0.40              -- default 0.40 (a stable buys a horse back for this share of its price; never above 0.5)
Config.NameMinLength = 2            -- default 2 (shortest horse name)
Config.NameMaxLength = 24           -- default 24 (longest horse name)
Config.Genders = true               -- default true (buyers pick stallion or mare; false = every horse is a stallion)

---------------------------------
-- at the stable
---------------------------------
Config.Interact = 'auto'            -- default 'auto' ('auto' = MULTItarget when it runs, else prompts; 'target'; 'prompt')
Config.PromptKey = 'J'              -- default 'J' (key name from MULTIcore's shared/keybinds.lua; stable prompt only)
Config.PromptDistance = 2.5         -- default 2.5 (metres from the stable hand at which the stable prompt shows; prompt mode)
Config.TargetIcon = 'fas fa-horse'  -- default 'fas fa-horse' (MULTItarget icon at the stable hand)
Config.TargetRadius = 1.2           -- default 1.2 (MULTItarget sphere size at the stable hand)
Config.TargetDistance = 2.5         -- default 2.5 (how close to stand to use the target)
-- The server re-checks every stable action: the player must stand this close to the stable hand
-- (needs OneSync, which MULTIcore servers run). false only when OneSync is off.
Config.ServerDistanceCheck = true   -- default true
Config.StableDistance = 8.0         -- default 8.0 (metres from the stable hand for buying, selling, storing ...)
Config.CheckIntervalMs = 1000       -- default 1000 (ms between client checks for stable hands and the horse)

Config.Npc = {
    Enabled = true,                 -- default true (a stable hand stands at every stable)
    SpawnDistance = 30.0,           -- default 30.0 (made when the player is this close, removed beyond it)
    ZOffset = -1.0,                 -- default -1.0 (added to the stable hand's z so he stands on the floor)
    LoadTimeoutMs = 5000,           -- default 5000 (give up loading the model after this long)
    Scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK', -- default 'WORLD_HUMAN_WRITE_NOTEBOOK' (what the stable hand does; '' = stands still)
}

Config.Blips = {
    Enabled = true,                 -- default true
    Style = 1664425300,             -- default 1664425300 (BlipAddForCoords style; the value RSG v2 scripts use) -- UNVERIFIED locally
    Sprite = 'blip_shop_horse',     -- default 'blip_shop_horse' (texture rsg-horses uses) -- UNVERIFIED locally
    Scale = 0.2,                    -- default 0.2
}

-- Moving a horse to another stable. Off = every horse can be taken out at any stable.
Config.Transfer = {
    Enabled = true,                 -- default true (a horse is taken out at the stable it stands in; others can be fetched for a fee)
    BaseFee = 1.00,                 -- default 1.00 (dollars for every transfer)
    PerMetre = 0.001,               -- default 0.001 (dollars per metre between the two stables)
}

---------------------------------
-- calling the horse
---------------------------------
Config.WhistleKey = 'H'             -- default 'H' (key name from MULTIcore's shared/keybinds.lua; H = the game's whistle, INPUT_WHISTLE 0x24978A28)
Config.WhistleCooldownMs = 3000     -- default 3000 (ms between two whistles)
Config.WalkDistance = 100.0         -- default 100.0 (a horse closer than this walks to you; farther away it is brought near you)
Config.SpawnDistance = 15.0         -- default 15.0 (how far behind the player a called horse appears)
Config.ArriveDistance = 4.0         -- default 4.0 (the horse stops walking this close to the player)
Config.WalkSpeed = 2.0              -- default 2.0 (walking speed to the player; 1.0 walk, 2.0 trot, 3.0 gallop)
Config.FollowSpeed = 1.5            -- default 1.5 (speed while following the player on foot)
Config.FleeDespawnMs = 8000         -- default 8000 (ms after "send away" before the horse is gone)
Config.LoadTimeoutMs = 10000        -- default 10000 (give up loading a horse model after this long)
Config.Blip = true                  -- default true (a blip with the horse's name follows the horse)
Config.OwnerOnlyRide = false        -- default false (true = only the owner can ride the horse)

---------------------------------
-- care
---------------------------------
Config.InteractDistance = 3.0       -- default 3.0 (metres to the horse for brushing, feeding, reviving and the saddlebags; the server allows +1.5)
Config.CareCooldownMs = 4000        -- default 4000 (ms between two care actions; the animation plays meanwhile)

-- Horse food. health / stamina are added to the horse's cores (0-100). Items missing from the
-- registry are skipped. The order is the order "Feed" tries them in.
Config.Feed = {
    { item = 'horse_carrot',    health = 10,  stamina = 10 },
    { item = 'horse_apple',     health = 15,  stamina = 15 },
    { item = 'haysnack',        health = 10,  stamina = 15 },
    { item = 'horsemeal',       health = 25,  stamina = 25 },
    { item = 'horsecarrot',     health = 10,  stamina = 10 },  -- rsg-horses' item names
    { item = 'horseapple',      health = 15,  stamina = 15 },
    { item = 'hay',             health = 10,  stamina = 15 },
    { item = 'horse_stimulant', health = 100, stamina = 100, heal = true }, -- heal = also restores lost health
}

Config.Brush = {
    Item = 'horse_brush',           -- default 'horse_brush' (item needed to brush; it is not used up)
    Stamina = 5,                    -- default 5 (stamina core points a brushing gives)
    CooldownSeconds = 60,           -- default 60 (a horse can be brushed for points once in this many seconds)
}

Config.Lantern = {
    Item = 'horse_lantern',         -- default 'horse_lantern' (item that hangs a lantern on the saddle; '' = off)
}

Config.Revive = {
    Item = 'horse_reviver',         -- default 'horse_reviver' (used on the fallen horse; it is used up)
    BodySeconds = 120,              -- default 120 (a fallen horse lies this long for a reviver, then the stable takes it in)
    StableFee = 10.00,              -- default 10.00 (dollars the stable charges to nurse a fallen horse back)
    Health = 50,                    -- default 50 (health and stamina cores after a revive)
}

Config.SaveStateSeconds = 60        -- default 60 (how often the horse's health and stamina are saved while it is out)

---------------------------------
-- saddlebags
---------------------------------
Config.Saddlebag = {
    Slots = 12,                     -- default 12
    MaxWeight = 15000,              -- default 15000 (grams)
    RequireEmptyToSell = true,      -- default true (a horse can't be sold while its saddlebags hold anything)
}

---------------------------------
-- horse interaction (MULTItarget on the horse, or prompts when you look at it)
---------------------------------
-- Control hashes from redm-info Controls.cs. Never PageDown.
Config.HorsePrompts = {
    Saddlebag = 0x5966D52A,         -- INPUT_OPEN_SATCHEL_HORSE_MENU
    Brush     = 0x63A38F2C,         -- INPUT_INTERACT_HORSE_BRUSH
    Feed      = 0x0D55A0F0,         -- INPUT_INTERACT_HORSE_FEED
    Revive    = 0xB0BCE5D6,         -- INPUT_INTERACT_HORSE_CARE
    Follow    = 0x763E4D27,         -- INPUT_HORSE_COMMAND_FOLLOW
    SendAway  = 0x4216AF06,         -- INPUT_HORSE_COMMAND_FLEE
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 8,                      -- default 8 (at most this many horse actions ...)
    WindowMs = 3000,                -- default 3000 (... in this many ms, per player)
}

---------------------------------
-- commands
---------------------------------
Config.Commands = {
    FindHorse = 'findhorse',        -- default 'findhorse' (lists your horses and where they stand; '' = off)
    SendAway = 'fleehorse',         -- default 'fleehorse' (sends your horse away; '' = off)
}
