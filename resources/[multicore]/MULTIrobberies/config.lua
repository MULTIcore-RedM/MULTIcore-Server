-- ============================================================
-- MULTIrobberies :: settings
-- Store tills: pick the cash register in any store for the till's cash.
-- Banks: pick the lock of the bank's gate (MULTIdoors), set a pipe charge
-- on the vault door, blow it open and empty the safes inside.
-- Money is in dollars (cents allowed). Every town and bank pays its own way.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

Config = Config or {}

Config.Locale = ''                  -- default '' ('' = MULTIcore's language; or 'en', 'de', ...)
Config.Debug = false                -- default false (true = print every robbery step in the server console)
Config.Interaction = 'auto'         -- default 'auto' ('auto' = MULTItarget when it runs, else a hold prompt; 'target'; 'prompt')
Config.PromptKey = 'G'              -- default 'G' (hold-key in prompt mode, a key name from MULTIcore's keybinds)
Config.NotifyDuration = 6000        -- default 6000 (ms a robbery note stays on screen)

---------------------------------
-- minigames
---------------------------------
-- Lock: a pin lock seen from the side. The mouse moves the pick along the pins and lifts them; one pin
--       binds at a time (it feels stiff) and sets with a click when held at the shear line.
-- Safe: a combination dial. Turn left to the heavy click, turn back right to the next click, and so on.
-- MULTIdoors uses the lock for its lockpickable doors (bank gates too) while this script runs.
Config.Minigames = {
    Enabled = true,                 -- false = ox_lib skill checks instead
    Lockpick = {
        easy   = { pins = 3, tolerance = 6, holdMs = 200, seconds = 40 },
        medium = { pins = 4, tolerance = 5, holdMs = 220, seconds = 45 },
        hard   = { pins = 6, tolerance = 4, holdMs = 260, seconds = 50 },
    },                              -- tolerance: pixels around the shear line that count; holdMs: how long to hold a pin there
    Safe = {
        easy   = { numbers = 3, tolerance = 2, seconds = 75 },
        medium = { numbers = 3, tolerance = 1, seconds = 75 },
        hard   = { numbers = 4, tolerance = 0, seconds = 90 },
    },                              -- numbers: how many in the combination; tolerance: numbers either side that still click
}

---------------------------------
-- the law
---------------------------------
Config.Law = {
    JobTypes = { leo = true },      -- job types (MULTIcore shared/jobs.lua `type`) that count as law and get alerts
    OnDutyOnly = true,              -- only lawmen on duty count and get alerts
    LawCanRob = false,              -- false = lawmen on duty may not rob
    BlipSeconds = 180,              -- how long the alert blip stays on the law's map
    BlipSprite = 1109348405,        -- blip sprite hash (MULTIdoors' alert value) -- UNVERIFIED (not in femga natives.json)
    BlipStyle = 1664425300,         -- BlipAddForCoords style hash (MULTIdoors' alert value) -- UNVERIFIED
}

---------------------------------
-- items
---------------------------------
Config.Lockpick = 'lockpick'        -- the lockpick item (MULTIdoors registers it; kept unless it breaks)
Config.Charge = 'pipe_charge'       -- the pipe charge dynamite item used on a vault door

-- Items this script adds to the item list when the inventory does not know them.
-- Images: MULTIimages names (stand-ins until own pictures are made).
Config.NewItems = {
    pipe_charge   = { label = 'Pipe Charge Dynamite', weight = 900, image = 'weapon_thrown_dynamite.png', description = 'A bundle of dynamite in an iron pipe. Made for vault doors.' },
    bank_bond     = { label = 'Bank Bond',            weight = 10,  image = 'goldclaimlicense.png',      description = 'A bearer bond from a bank vault. A fence will pay for it.' },
    jewelry_box   = { label = 'Jewellery Box',        weight = 600, image = 'cigar_box_preimium.png',    description = 'A locked box from a safe deposit. Something rattles inside.' },
    gold_ring     = { label = 'Gold Ring',            weight = 10,  image = 'smallnugget.png',           description = 'A heavy gold ring.' },
    pearl_necklace= { label = 'Pearl Necklace',       weight = 40,  image = 'resource_diamond.png',      description = 'A string of real pearls.' },
    gold_watch    = { label = 'Gold Pocket Watch',    weight = 120, image = 'mediumnugget.png',          description = 'A gold pocket watch with an engraved lid.' },
    diamond_brooch= { label = 'Diamond Brooch',       weight = 20,  image = 'resource_diamond.png',      description = 'A brooch set with small diamonds.' },
}

---------------------------------
-- store tills
---------------------------------
Config.Registers = {
    Enabled = true,
    Models = {                      -- cash register props (redm-info objects.lua, p_store.rpf)
        'p_register01x', 'p_register03x', 'p_register04x', 'p_register05x',
        'p_register06x', 'p_register07x', 'p_register08x',
    },
    Distance = 1.8,                 -- metres from the till to pick it
    ServerDistance = 4.0,           -- server: largest distance between the player and the till
    MinLaw = 0,                     -- lawmen on duty needed to pick a till (0 = none)
    CooldownMinutes = 45,           -- one till can be picked again after this
    PlayerCooldownSeconds = 120,    -- one player waits this long between two tills
    Lockpick = 'medium',            -- lock minigame level (Config.Minigames.Lockpick)
    BreakChance = 0.35,             -- chance the lockpick breaks when the skill check fails
    EmptyMs = 6000,                 -- how long emptying the till takes (progress bar, ms)
    AlertChance = 0.6,              -- chance the clerk gets word to the law (0 .. 1)
    Anim = { dict = 'script_common@jail_cell@unlock@key', clip = 'action' }, -- MULTIdoors' lockpick animation
    -- cash in a till before the town's multiplier: random between Min and Max dollars
    Min = 8.0,
    Max = 30.0,
    OtherTowns = 0.6,               -- multiplier for a till outside every town below
}

-- Town pay: multiplies till cash. Centres are rough middles of each place (map x / y).
Config.Towns = {
    { name = 'Saint Denis', x = 2560.0,  y = -1230.0, radius = 520.0, pay = 2.5 },
    { name = 'Blackwater',  x = -800.0,  y = -1300.0, radius = 260.0, pay = 2.0 },
    { name = 'Rhodes',      x = 1310.0,  y = -1310.0, radius = 230.0, pay = 1.6 },
    { name = 'Valentine',   x = -290.0,  y = 760.0,   radius = 260.0, pay = 1.3 },
    { name = 'Strawberry',  x = -1790.0, y = -400.0,  radius = 220.0, pay = 1.1 },
    { name = 'Annesburg',   x = 2930.0,  y = 1330.0,  radius = 260.0, pay = 1.0 },
    { name = 'Van Horn',    x = 2970.0,  y = 540.0,   radius = 200.0, pay = 0.9 },
    { name = 'Armadillo',   x = -3670.0, y = -2600.0, radius = 220.0, pay = 1.0 },
    { name = 'Tumbleweed',  x = -5500.0, y = -2940.0, radius = 220.0, pay = 0.9 },
    { name = 'Emerald Ranch', x = 1410.0, y = 320.0,  radius = 200.0, pay = 0.8 },
}

---------------------------------
-- banks
---------------------------------
-- gates: MULTIdoors rule ids (config/locks.lua). The bank is open to robbery once one of them
--        was lockpicked (Config.Bank.GateMustBePicked) or stands unlocked.
-- vault: the MULTIdoors rule of the vault door (lockpickable = false there; only a charge opens it).
-- safes: how many safes are in the vault. Their spots come from data/safes.json (set in game with
--        /robsafe), then from safe props the game placed by the vault, else spots inside the vault door.
-- pay:   multiplies every cash and item roll in that bank's safes.
Config.Banks = {
    { id = 'saintdenis', label = 'Saint Denis Bank',  gates = { 'sd_bank_manager', 'sd_bank_private' }, vault = 'sd_bank_vault',  safes = 6, pay = 3.0, minLaw = 0 },
    { id = 'blackwater', label = 'Blackwater Bank',   gates = { 'blk_bank_inner' },                     vault = 'blk_bank_vault', safes = 5, pay = 2.2, minLaw = 0 },
    { id = 'rhodes',     label = 'Rhodes Bank',       gates = { 'rho_bank_inner3' },                    vault = 'rho_bank_vault', safes = 4, pay = 1.6, minLaw = 0 },
    { id = 'valentine',  label = 'Valentine Bank',    gates = { 'val_bank_counter_r', 'val_bank_counter_l' }, vault = 'val_bank_vault', safes = 4, pay = 1.2, minLaw = 0 },
}

Config.Bank = {
    GateMustBePicked = true,        -- true = the gate must have been lockpicked (not opened with a key) for the vault charge
    PlantDistance = 2.5,            -- metres from the vault door to set the charge
    PlantMs = 8000,                 -- how long setting the charge takes (ms)
    FuseSeconds = 12,               -- seconds from the lit fuse to the blast
    ExplosionType = 26,             -- ADD_EXPLOSION type (femga enum: 25 dynamite, 26 dynamite stack, 29 placed dynamite)
    ExplosionDamage = 1.0,          -- ADD_EXPLOSION damage scale (stand clear!)
    CameraShake = 1.5,
    ChargeProp = 'p_dynamite01x',   -- prop on the vault door while the fuse burns (objects.lua, p_armory.rpf)
    SafeRadius = 0.8,               -- MULTItarget sphere size on a safe
    SpotHeight = 1.0,               -- metres above the floor for a safe spot found without a safe prop
    SafeDistance = 3.0,             -- server: largest distance between the player and a safe
    SafeScanRadius = 9.0,           -- metres around the vault door to look for safe props
    SafeModels = {                  -- safe props the game places in vaults (objects.lua)
        'p_bank_safe_med_l', 'p_bank_safe_r', 'p_safebla01x', 'p_safenbd01x', 'p_safenbd02x', 'p_safetydepositbox01x',
    },
    Safe = 'medium',                -- safe dial minigame level (Config.Minigames.Safe)
    Anim = { dict = 'script_common@jail_cell@unlock@key', clip = 'action' }, -- while cracking and emptying a safe (the till animation)
    LootMs = 7000,                  -- how long emptying a safe takes (ms)
    ResetMinutes = 90,              -- the vault is fixed and locked again after this (and the bank can be robbed again)
    AlertOnGate = true,             -- tell the law when a bank gate is picked
    AlertOnCharge = true,           -- tell the law when the vault blows (always loud)
}

-- What one safe holds. Each line is rolled on its own: `chance` 0 .. 1, an amount between min and max.
-- Cash and the item amounts are multiplied by the bank's pay (items rounded down, at least min).
Config.SafeLoot = {
    { cash = true,             chance = 1.00, min = 60.0, max = 180.0 },
    { item = 'goldbar',        chance = 0.35, min = 1, max = 2 },
    { item = 'silverbar',      chance = 0.50, min = 1, max = 3 },
    { item = 'bank_bond',      chance = 0.45, min = 1, max = 4 },
    { item = 'jewelry_box',    chance = 0.25, min = 1, max = 1 },
    { item = 'gold_ring',      chance = 0.35, min = 1, max = 3 },
    { item = 'pearl_necklace', chance = 0.20, min = 1, max = 1 },
    { item = 'gold_watch',     chance = 0.25, min = 1, max = 2 },
    { item = 'diamond_brooch', chance = 0.12, min = 1, max = 1 },
}

-- Opening a jewellery box (use it from the inventory) gives one roll from this list.
Config.JewelryBox = {
    Enabled = true,
    Rolls = 2,                      -- how many lines are drawn
    Loot = {
        { item = 'gold_ring',      weight = 40, min = 1, max = 2 },
        { item = 'pearl_necklace', weight = 25, min = 1, max = 1 },
        { item = 'gold_watch',     weight = 20, min = 1, max = 1 },
        { item = 'diamond_brooch', weight = 10, min = 1, max = 1 },
        { cash = true,             weight = 25, min = 10.0, max = 40.0 },
    },
}

---------------------------------
-- admin
---------------------------------
Config.Admin = {
    Ace = 'multirobberies.admin',   -- ACE for the admin commands, e.g.  add_ace group.admin multirobberies.admin allow
    Groups = { 'admin', 'god' },    -- MULTIcore permission groups that may use them as well
    SafeCommand = 'robsafe',        -- /robsafe        face a safe: adds a spot on the safe in front of you to the nearest bank (data/safes.json)
                                    -- /robsafe clear  removes that bank's spots
    ResetCommand = 'robreset',      -- /robreset [bank id]  fixes and locks a vault now (all banks when no id)
}
