-- ============================================================
-- MULTIfarming :: settings
-- Basic farming for MULTIcore: buy seeds at the general store, plant them with a hoe in the
-- satchel, water the crops with a watering can and harvest them for MULTIinventory items the
-- stores buy. Deliberately simple (no soil quality, no fertiliser, no farm plots, no workers),
-- so premium farming scripts are still worth buying.
-- Crops: config/crops.lua
-- ============================================================

Config = Config or {}

Config.Locale = nil                 -- default nil (use MULTIcore's language (MULTIConfig.Language), else 'en'); e.g. 'de'
Config.Debug = false                -- default false (true = print every plant, harvest and refusal in the server console)

---------------------------------
-- general rules (server)
---------------------------------
Config.PromptKey = 'J'              -- default 'J' (key name from MULTIcore's shared/keybinds.lua, for the hold prompt without MULTItarget)
Config.Interaction = 'auto'         -- default 'auto' ('auto' = MULTItarget on the crop when MULTItarget runs, else a hold prompt; 'target'; 'prompt')
Config.TargetDistance = 2.0         -- default 2.0 (MULTItarget reach to a crop)
Config.RateLimitMs = 400            -- default 400 (ignore a second request of the same kind from one player within this many ms)
Config.FinishSlackMs = 750          -- default 750 (a finish may come this many ms before the work time is up: network lag)
Config.PendingTimeoutMs = 60000     -- default 60000 (an unfinished job expires after this many ms)
Config.InteractDistance = 3.5       -- default 3.5 (server: largest distance in metres between the player and the crop or planting spot)
Config.AllowWithoutPosition = false -- default false (true = accept work when the server cannot see the player's position, e.g. no OneSync)
Config.NotifyDuration = 5000        -- default 5000 (ms a farming note stays on screen)

---------------------------------
-- planting
---------------------------------
Config.Planting = {
    Tool = 'hoe',                   -- default 'hoe' (item the player must carry to plant; it is not used up)
    DurationMs = 6000,              -- default 6000 (the planting work)
    Scenario = 'WORLD_HUMAN_FARMER_WEEDING', -- default 'WORLD_HUMAN_FARMER_WEEDING' (the game's weeding scenario)
    MaxPlantsPerPlayer = 20,        -- default 20 (crops one character may have in the ground, withered ones included)
    MinSpacing = 1.5,               -- default 1.5 (metres between two crops)
    Forward = 0.8,                  -- default 0.8 (the seed goes this many metres in front of the player)
    MaxGroundStep = 1.5,            -- default 1.5 (client: the ground at the spot may be at most this far above or below the feet)
    NoTowns = true,                 -- default true (client: no planting inside a town's map zone)
    NoInteriors = true,             -- default true (client: no planting inside buildings)
    NoWater = true,                 -- default true (client: no planting while standing in water)
    NoRoads = true,                 -- default true (client: no planting on roads, the game's road check; UNVERIFIED how many paths it knows)
    StartWater = 30,                -- default 30 (water % a fresh crop starts with)
}

-- Optional: places where planting is allowed, checked on the server. Empty = anywhere
-- (the client still refuses towns, interiors, water and roads). Example:
--   { coords = vector3(-850.0, -1300.0, 43.0), radius = 60.0 },
Config.FarmZones = {}               -- default {} (planting allowed anywhere)

---------------------------------
-- watering
---------------------------------
Config.Watering = {
    Can = 'wateringcan',            -- default 'wateringcan' (usable item; its info.water holds the waterings left)
    CanUses = 5,                    -- default 5 (waterings in one full can)
    Amount = 50,                    -- default 50 (water % one watering adds to a crop, up to 100)
    DurationMs = 4000,              -- default 4000 (the watering work)
    Scenario = 'WORLD_HUMAN_BUCKET_POUR_LOW', -- default 'WORLD_HUMAN_BUCKET_POUR_LOW' (the game's low bucket pour)
    FillDurationMs = 5000,          -- default 5000 (filling the can at a river or lake)
    FillScenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- default 'WORLD_HUMAN_CROUCH_INSPECT'
    FillNoSwimming = true,          -- default true (not while swimming: the player must stand in the water)
    UseRange = 2.5,                 -- default 2.5 (client: using the can waters the nearest crop within this many metres)
}

---------------------------------
-- growing and withering (minutes are real minutes; per crop times are in config/crops.lua)
---------------------------------
Config.Growth = {
    DryWitherMinutes = 60,          -- default 60 (a crop that is not ripe withers after this long without water)
    RipeWitherMinutes = 120,        -- default 120 (a ripe crop withers after this long unharvested)
    DeadRemoveMinutes = 30,         -- default 30 (a withered crop is taken away after this long)
    CountOfflineTime = false,       -- default false (true = crops keep growing, drying and withering while the server is off)
    SweepSeconds = 60,              -- default 60 (how often the server looks at every crop for stage changes and withering)
    DeadProp = 'crp_tobaccoburnt_bb_sim', -- default 'crp_tobaccoburnt_bb_sim' (prop of a withered crop; objects.lua, rdr_inst_crops.rpf; UNVERIFIED look)
}

---------------------------------
-- harvesting
---------------------------------
Config.Harvest = {
    OwnerOnly = true,               -- default true (only the character who planted a crop may harvest it; false = anyone)
    DurationMs = 5000,              -- default 5000 (the harvest work)
    Scenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- default 'WORLD_HUMAN_CROUCH_INSPECT'
    RemoveDurationMs = 4000,        -- default 4000 (digging up a crop)
    RemoveScenario = 'WORLD_HUMAN_FARMER_RAKE', -- default 'WORLD_HUMAN_FARMER_RAKE'
}

---------------------------------
-- crops in the world (client)
---------------------------------
Config.Props = {
    LoadRange = 80.0,               -- default 80.0 (crops within this many metres are put into the world)
    UnloadRange = 100.0,            -- default 100.0 (crops further than this are taken out again)
    ModelTimeoutMs = 5000,          -- default 5000 (give up on a model that does not load)
}

---------------------------------
-- admin
---------------------------------
Config.Admin = {
    Groups = { 'admin', 'god' },    -- default { 'admin', 'god' } (MULTIcore permission levels allowed to use /farmclear)
    Ace = 'multifarming.admin',     -- default 'multifarming.admin' (an ace that also allows /farmclear)
    ClearRadius = 50.0,             -- default 50.0 (metres /farmclear works around the admin when no radius is given)
}

-- Items MULTIfarming adds to MULTIinventory when the registry does not have them yet
-- (weight in grams). The crop items (corn, potato ...) already exist in MULTIcore's items.
Config.NewItems = {
    hoe         = { name = 'hoe',         label = 'Hoe',           weight = 1200, type = 'item', image = 'hoe.png',         unique = false, useable = false, shouldClose = true, description = 'A garden hoe for breaking soil. Needed to plant seeds.', category = 'tools' },
    wateringcan = { name = 'wateringcan', label = 'Watering Can',  weight = 900,  type = 'item', image = 'wateringcan.png', unique = true,  useable = true,  shouldClose = true, description = 'A tin watering can. Fill it at a river or lake, then water your crops.', category = 'tools' },
    seed_corn    = { name = 'seed_corn',    label = 'Corn Seeds',    weight = 20, type = 'item', image = 'seed_corn.png',    unique = false, useable = true, shouldClose = true, description = 'A packet of corn seed. Plant it in open ground.', category = 'farming' },
    seed_potato  = { name = 'seed_potato',  label = 'Seed Potatoes', weight = 60, type = 'item', image = 'seed_potato.png',  unique = false, useable = true, shouldClose = true, description = 'Seed potatoes for planting in open ground.', category = 'farming' },
    seed_tomato  = { name = 'seed_tomato',  label = 'Tomato Seeds',  weight = 20, type = 'item', image = 'seed_tomato.png',  unique = false, useable = true, shouldClose = true, description = 'A packet of tomato seed. Plant it in open ground.', category = 'farming' },
    seed_carrot  = { name = 'seed_carrot',  label = 'Carrot Seeds',  weight = 20, type = 'item', image = 'seed_carrot.png',  unique = false, useable = true, shouldClose = true, description = 'A packet of carrot seed. Plant it in open ground.', category = 'farming' },
    seed_onion   = { name = 'seed_onion',   label = 'Onion Sets',    weight = 40, type = 'item', image = 'seed_onion.png',   unique = false, useable = true, shouldClose = true, description = 'Small onion bulbs for planting in open ground.', category = 'farming' },
    seed_wheat   = { name = 'seed_wheat',   label = 'Wheat Seed',    weight = 40, type = 'item', image = 'seed_wheat.png',   unique = false, useable = true, shouldClose = true, description = 'A bag of seed wheat. Plant it in open ground.', category = 'farming' },
    seed_pumpkin = { name = 'seed_pumpkin', label = 'Pumpkin Seeds', weight = 20, type = 'item', image = 'seed_pumpkin.png', unique = false, useable = true, shouldClose = true, description = 'A packet of pumpkin seed. Plant it in open ground.', category = 'farming' },
    seed_tobacco = { name = 'seed_tobacco', label = 'Tobacco Seeds', weight = 10, type = 'item', image = 'seed_tobacco.png', unique = false, useable = true, shouldClose = true, description = 'A packet of tobacco seed. Plant it in open ground.', category = 'farming' },
}
