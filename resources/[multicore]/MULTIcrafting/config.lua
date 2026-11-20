-- ============================================================
-- MULTIcrafting settings (part of MULTIcore by RINGO (RINGOscripting), GPL v3)
-- Recipes are in config/recipes.lua, fixed stations (kitchens, workbenches) in
-- config/stations.lua, the items this resource adds in config/items.lua.
-- Times are real seconds unless the name says Ms. Distances are metres.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = setr multicore_locale, else English)
Config.Debug = false                -- default false (prints every craft and every refusal to the server console)

---------------------------------
-- opening the crafting screen
---------------------------------
Config.Interact = 'auto'            -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target' = MULTItarget; 'prompt' = hold-key prompt at stations and campfires)
Config.PromptKey = 'G'              -- default 'G' (key name from MULTIcore's shared/keybinds.lua; prompt mode only)
Config.PromptDistance = 2.0         -- default 2.0 (how close the player must stand for a station / campfire prompt to show; prompt mode only)
Config.TargetIcon = 'fas fa-hammer' -- default 'fas fa-hammer' (MULTItarget icon; target mode only)
Config.TargetRadius = 1.2           -- default 1.2 (size of the MULTItarget sphere on a fixed station; target mode only)
Config.TargetDistance = 2.0         -- default 2.0 (how close the player must stand to use a target; target mode only)
Config.Command = 'craft'            -- default 'craft' (/craft opens the nearest station, or hand crafting when none is near; '' = no command)
Config.ScanIntervalMs = 1000        -- default 1000 (how often the client looks for campfires / anvils nearby)
Config.ScanRadius = 3.0             -- default 3.0 (how far the client looks for a world campfire / anvil prop)
Config.CloseDistance = 4.0          -- default 4.0 (the screen closes when the player walks this far from the station)

---------------------------------
-- crafting
---------------------------------
Config.Craft = {
    MaxBatch = 10,                  -- default 10 (most crafts of one recipe started at once; time adds up)
    RateLimitMs = 750,              -- default 750 (server refuses requests from one player closer together than this)
    TimeToleranceMs = 1500,         -- default 1500 (a finish may arrive this much earlier than the recipe time, for lag)
    MaxWaitMs = 30000,              -- default 30000 (server forgets an unfinished craft this long after it should have ended)
    CancelKey = 'X',                -- default 'X' (key name from MULTIcore's shared/keybinds.lua that stops crafting)
    CancelDistance = 2.5,           -- default 2.5 (crafting stops if the player moves this far from where it began)
    Unarm = true,                   -- default true (put the weapon away while crafting)
    ReopenMenu = true,              -- default true (the crafting screen opens again after a craft)
    BlockWhenDead = true,           -- default true (no crafting while dead or down)
    -- Inputs are taken only when crafting finishes (inputs and output change in one step on the server),
    -- so stopping early never costs anything.
}

---------------------------------
-- station types: what a station is, how close the player must be, the animation
--   scenario     redm-info Scenarios.lua name played while crafting (false = none)
--   distance     how close to the station the server allows crafting
--   worldProps   game props that count as this station anywhere on the map (redm-info objects.lua names).
--                The server cannot see world props: it trusts the client that the prop is there and only
--                checks that the player stands within `distance` of the coordinates sent. Set
--                Config.AllowWorldProps = false to accept only fixed stations and placed campfires.
--   job / grade  optional: only these jobs (MULTIcore job names, string or list) at this grade or higher
---------------------------------
Config.AllowWorldProps = true       -- default true (world campfires / anvils count as stations, see above)

Config.StationTypes = {
    hand = {
        enabled = true,             -- default true (crafting from the satchel, anywhere)
        label = 'station_hand',     -- locale key
        scenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- default (redm-info Scenarios.lua; also used by RSG v2 scripts)
    },
    campfire = {
        enabled = true,
        label = 'station_campfire',
        scenario = 'WORLD_HUMAN_FIRE_TEND_KNEEL', -- default (redm-info Scenarios.lua)
        distance = 3.0,             -- default 3.0
        worldProps = {              -- redm-info objects.lua
            'p_campfire01x', 'p_campfire02x', 'p_campfire03x', 'p_campfire04x', 'p_campfire05x',
            'p_campfire_06x', 'p_campfirecombined01x', 'p_campfirecombined02x', 'p_campfirecombined03x',
            'p_campfirecombined04x', 'p_campfirecook01x', 'p_campfirecook02x', 'p_campfire02x_script',
            'p_campfire05x_script',
        },
    },
    cooking = {
        enabled = true,
        label = 'station_cooking',
        scenario = 'WORLD_HUMAN_CLEAN_TABLE', -- default (redm-info Scenarios.lua: standing work at a counter)
        distance = 3.0,
    },
    gunsmith = {
        enabled = true,
        label = 'station_gunsmith',
        scenario = 'WORLD_HUMAN_HAMMER_TABLE', -- default (redm-info Scenarios.lua)
        distance = 3.0,
    },
    blacksmith = {
        enabled = true,
        label = 'station_blacksmith',
        scenario = 'WORLD_HUMAN_HAMMER_TABLE', -- default (redm-info Scenarios.lua)
        distance = 3.0,
        worldProps = { 'p_anvil01x', 'p_forge01x' }, -- redm-info objects.lua (the anvils and forges in town smithies)
    },
}

---------------------------------
-- campfires players put down (the 'campfire' item, sold in general stores)
---------------------------------
Config.Campfire = {
    Enabled = true,                 -- default true (the campfire item can be used to put a campfire down)
    Item = 'campfire',              -- default 'campfire' (item taken when the fire is put down)
    Model = 'p_campfire02x',        -- default 'p_campfire02x' (redm-info objects.lua)
    MaxPerPlayer = 1,               -- default 1 (fires one character may have burning at once)
    LifetimeMinutes = 20,           -- default 20 (the fire burns out after this long)
    PlaceDistance = 3.0,            -- default 3.0 (how far from the player the fire may be put down; checked on the server)
    PlaceAhead = 1.2,               -- default 1.2 (metres in front of the player the fire goes)
    MinSpacing = 2.0,               -- default 2.0 (no new fire this close to another placed fire)
    PlaceScenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- default (redm-info Scenarios.lua; played while setting it up)
    PlaceMs = 3000,                 -- default 3000 (how long setting it up takes)
    AnyoneCanPutOut = false,        -- default false (only the owner may put a placed fire out; admins always may)
    StreamDistance = 120.0,         -- default 120.0 (clients draw placed fires within this distance)
    AdminAce = 'command',           -- default 'command' (ace that counts as admin for putting fires out)
}

---------------------------------
-- jobs
---------------------------------
Config.RequireDuty = false          -- default false (true = job-locked recipes and stations need the player on duty)

---------------------------------
-- blips for fixed stations (config/stations.lua)
---------------------------------
Config.Blips = {
    Enabled = false,                -- default false (blips on the map for fixed stations that set `blip = true`)
    Style = 1664425300,             -- default 1664425300 (BlipAddForCoords style RSG v2 scripts and MULTIstores use) -- UNVERIFIED locally
    Scale = 0.2,                    -- default 0.2
    Sprite = 'blip_shop_blacksmith', -- default 'blip_shop_blacksmith' (sprite name; a station may set its own `blipSprite`) -- UNVERIFIED
}

---------------------------------
-- look
---------------------------------
Config.ImagePaths = nil             -- default nil (nil = the same item picture folders as MULTIinventory; or a list of nui:// folders)
