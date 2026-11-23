-- ============================================================
-- MULTIgathering :: settings
-- Basic gathering for MULTIcore: fishing, mining, gold panning, lumber and herb picking give
-- MULTIinventory items that the trade jobs can sell. Deliberately simple (no skills, no XP,
-- no tool wear UI), so premium gathering scripts are still worth buying.
-- Lists: config/fish.lua, config/mining.lua, config/lumber.lua, config/panning.lua,
--        config/herbs.lua, config/herb_spots.lua
-- ============================================================

Config = Config or {}

Config.Locale = nil                 -- default nil (use MULTIcore's language (MULTIConfig.Language), else 'en'); e.g. 'de'
Config.Debug = false                -- default false (true = print every reward and refusal in the server console)

---------------------------------
-- general rules (server)
---------------------------------
Config.PromptKey = 'J'              -- default 'J' (key name from MULTIcore's shared/keybinds.lua, for the mine / chop prompts)
Config.RateLimitMs = 400            -- default 400 (ignore a second request of the same kind from one player within this many ms)
Config.FinishSlackMs = 750          -- default 750 (a finish may come this many ms before the work time is up: network lag)
Config.PendingTimeoutMs = 60000     -- default 60000 (an unfinished mine / chop / pan expires after this many ms)
Config.ZTolerance = 12.0            -- default 12.0 (metres of height difference allowed at a spot; coords may be a little off the ground)
Config.AllowWithoutPosition = false -- default false (true = accept work when the server cannot see the player's position, e.g. no OneSync)
Config.NotifyDuration = 5000        -- default 5000 (ms a gathering note stays on screen)
Config.BlipStyle = 1664425300       -- default 1664425300 (BlipAddForCoords style, the value RSG v2 scripts and MULTIstores use)
Config.BlipScale = 0.2              -- default 0.2

-- Resources that pay for the same activity. When one of them is started, MULTIgathering
-- gives nothing for that activity (so nobody is paid twice). Add any premium script here.
Config.StandDownFor = {
    fishing = { 'rsg-fishing', 'vorp_fishing', 'RINGOoutdoors' }, -- default rsg-fishing, vorp_fishing, RINGOoutdoors
    mining  = { 'RINGOminingcorp' },                              -- default RINGOminingcorp
    panning = {},                                                 -- default {} (no known panning script)
    lumber  = { 'rsg-lumberjack', 'RINGOlumberjack' },            -- default rsg-lumberjack, RINGOlumberjack
    herbs   = { 'rsg-herbalist', 'RINGOherbs' },                  -- default rsg-herbalist, RINGOherbs
}

-- Items MULTIgathering adds to MULTIinventory when the registry does not have them yet
-- (RSG item shape; weight in grams). Everything else it uses already exists in MULTIcore's items.
Config.NewItems = {
    goldpan = { name = 'goldpan', label = 'Gold Pan', weight = 500, type = 'item', image = 'goldpan.png', unique = false, useable = true, shouldClose = true, description = 'A shallow iron pan for washing gold out of river gravel.', category = 'tools' },
}

---------------------------------
-- fishing (the game's own fishing with the rod)
---------------------------------
Config.Fishing = {
    Enabled = true,                 -- default true
    Rod = 'weapon_fishingrod',      -- default 'weapon_fishingrod' (rod item the player must carry and hold)
    -- bait items: using one while holding the rod puts it on the hook; one bait is used per cast
    Baits = {
        'p_baitbread01x', 'p_baitcorn01x', 'p_baitcheese01x', 'p_baitcricket01x', 'p_baitworm01x',
        'p_finisdfishlure01x', 'p_finisdfishlurelegendary01x',
    },
    CastWindowSeconds = 300,        -- default 300 (a used bait pays for one fish caught within this many seconds)
    CatchCooldownMs = 3000,         -- default 3000 (one fish per player within this many ms)
    CheckBaitFish = true,           -- default true (the fish must be one the bait attracts, Config.BaitFish)
    WeightMultiplier = 54.25,       -- default 54.25 (game weight units -> kg, as rsg-fishing)
    ReelSpeed = 0.025,              -- default 0.025 (how fast holding crouch reels the hook in)
    Difficulty = 500,               -- default 500 (how hard the fish pulls back while reeling)
    StruggleChance = 0.3,           -- default 0.3 (chance per check that a hooked fish struggles)
    HookRange = 1.6,                -- default 1.6 (metres between the hook and a fish before it can bite)
    LureRange = 50.0,               -- default 50.0 (metres around the hook in which fish are drawn to the bait)
    RemoveHeldFish = true,          -- default true (a fish the game puts in the player's hands is removed; it is an item now)
}

---------------------------------
-- mining (pickaxe at rock spots, config/mining.lua)
---------------------------------
Config.Mining = {
    Enabled = true,                 -- default true
    Tool = 'pickaxe',               -- default 'pickaxe' (item the player must carry)
    DurationMs = 8000,              -- default 8000 (one swing set)
    CooldownMs = 2000,              -- default 2000 (pause between two finished swings per player)
    ToolBreakChance = 0,            -- default 0 (% chance the pickaxe breaks on a finished swing)
    Interaction = 'auto',           -- default 'auto' ('auto' = MULTItarget "Mine" at the rock face when MULTItarget runs, else the hold-key prompt; 'target'; 'prompt')
    TargetIcon = 'fas fa-hammer',   -- default 'fas fa-hammer' (MULTItarget icon)
    TargetDistance = 2.5,           -- default 2.5 (MULTItarget reach to the rock face; the player must also stand within the spot's radius)
    Scenario = 'WORLD_HUMAN_PICKAXE_WALL', -- default 'WORLD_HUMAN_PICKAXE_WALL' (the game's own pickaxe scenario, brings its own pick)
    Blips = true,                   -- default true (a map blip on every mine)
    BlipSprite = 'blip_gold',       -- default 'blip_gold' (blip texture name, as rsg-goldclaim uses it)
}

---------------------------------
-- gold panning (gold pan in shallow river or creek water)
---------------------------------
Config.Panning = {
    Enabled = true,                 -- default true
    Tool = 'goldpan',               -- default 'goldpan' (usable item; using it in water starts panning)
    DurationMs = 15000,             -- default 15000 (one pan)
    CooldownMs = 3000,              -- default 3000 (pause between two pans per player)
    ToolBreakChance = 0,            -- default 0 (% chance the pan is lost on a finished pan)
    Scenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- default 'WORLD_HUMAN_CROUCH_INSPECT'
    Prop = 'p_miningpan01x',        -- default 'p_miningpan01x' (pan held in the hand while panning; false = none)
    PropBone = 7966,                -- default 7966 (right-hand bone id, as rsg-lumberjack holds its axe)
    PropPos = vector3(0.08, 0.0, -0.05),  -- UNVERIFIED offset in the hand (adjust in game)
    PropRot = vector3(0.0, 0.0, 0.0),     -- UNVERIFIED rotation in the hand
    NoSwimming = true,              -- default true (not while swimming: the player must stand in the water)
}

---------------------------------
-- lumber (axe in tree zones, config/lumber.lua)
---------------------------------
Config.Lumber = {
    Enabled = true,                 -- default true
    Tool = 'axe',                   -- default 'axe' (item the player must carry)
    DurationMs = 7000,              -- default 7000 (one chop, as rsg-lumberjack)
    CooldownMs = 3000,              -- default 3000 (pause between two finished chops per player)
    ToolBreakChance = 0,            -- default 0 (% chance the axe breaks on a finished chop)
    Interaction = 'auto',           -- default 'auto' ('target' = MULTItarget on tree models, 'prompt' = key prompt anywhere in a zone, 'auto' = target when MULTItarget runs)
    TargetIcon = 'fas fa-tree',     -- default 'fas fa-tree' (MULTItarget icon)
    TargetDistance = 2.0,           -- default 2.0 (MULTItarget reach to a tree)
    ChopsPerTree = 3,               -- default 3 (chops one tree gives before it is felled; 0 = no limit per tree, only the zone charges)
    TreeRegrowMinutes = 20,         -- default 20 (a felled tree can be chopped again after this many minutes)
    TreeReach = 6.0,                -- default 6.0 (server: largest distance between the player and the tree being chopped)
    -- the chop animation and the axe in the hand (both as rsg-lumberjack plays them)
    Anim = { dict = 'amb_work@world_human_tree_chop_new@working@pre_swing@male_a@trans', clip = 'pre_swing_trans_after_swing', flag = 17 },
    Prop = { model = 'p_axe02x', bone = 7966, pos = vector3(0.03, 0.03, 0.02), rot = vector3(0.0, 0.0, -1.5) },
    Blips = true,                   -- default true (a map blip on every lumber zone)
    BlipSprite = 1904459580,        -- default 1904459580 (blip sprite hash, as rsg-lumberjack uses it)
}

---------------------------------
-- herbs (the game's own herb plants, config/herbs.lua + config/herb_spots.lua)
---------------------------------
Config.Herbs = {
    Enabled = true,                 -- default true
    LoadRange = 100.0,              -- default 100.0 (plants within this many metres are put into the world)
    UnloadRange = 120.0,            -- default 120.0 (plants further than this are taken out again)
    PickRange = 2.5,                -- default 2.5 (client: how close the player must be to pick)
    MaxDistance = 4.0,              -- default 4.0 (server: largest accepted distance to the plant)
    PickDurationMs = 3000,          -- default 3000 (the picking animation)
    Scenario = 'WORLD_HUMAN_GATHER_HERBS', -- default (scenario as rsg-herbalist uses it)
    CooldownMs = 2500,              -- default 2500 (one plant per player within this many ms)
    RegrowMinutes = 10,             -- default 10 (a picked plant grows back after this many minutes)
    Amount = { min = 1, max = 2 },  -- default 1-2 (how many of the herb one plant gives)
    CompositeTimeoutMs = 10000,     -- default 10000 (give up on a plant model that does not stream in)
}
