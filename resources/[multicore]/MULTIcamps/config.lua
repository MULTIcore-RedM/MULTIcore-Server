-- ============================================================
-- MULTIcamps settings (part of MULTIcore by RINGO (RINGOscripting), GPL v3)
-- A basic camp a character pitches in the wild with a tent kit.
-- Places where camps are not allowed (towns) are in config/towns.lua.
-- Prices are dollars with cents at 1899 level.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = MULTIcore's language (MULTIConfig.Language), else English)
Config.Debug = false                -- default false (prints placements, pack-ups and decay to the server console)

---------------------------------
-- the kit and the rules for pitching a camp
---------------------------------
Config.KitItem = 'tent'             -- default 'tent' (item used to pitch a camp; given back when the camp is packed up)
Config.MaxCampsPerCharacter = 1     -- default 1 (camps one character may have standing at once)
Config.PlaceDistance = 8.0          -- default 8.0 (metres from the player the camp may be pitched; checked on the server)
Config.MinCampDistance = 60.0       -- default 60.0 (metres a new camp must keep from any other camp)
Config.MinRoadDistance = 15.0       -- default 15.0 (metres a new camp must keep from the nearest road; checked by the game, 0 = off)
Config.MaxSlope = 0.85              -- default 0.85 (ground must be at least this flat: up-component of the ground normal, 1.0 = level)
Config.PitchMs = 8000               -- default 8000 (how long pitching or packing up takes)
Config.PitchScenario = 'WORLD_HUMAN_FIRE_TEND_KNEEL' -- default (scenario while pitching / packing; redm-info Scenarios.lua)

---------------------------------
-- placement preview (a see-through tent in front of the player)
---------------------------------
Config.Preview = {
    Alpha = 160,                    -- default 160 (0-255, see-through level of the preview tent)
    StartAhead = 4.0,               -- default 4.0 (metres in front of the player the preview starts)
    MinAhead = 2.0,                 -- default 2.0 (closest the preview can be pulled)
    MaxAhead = 7.0,                 -- default 7.0 (farthest the preview can be pushed; keep below PlaceDistance)
    MoveStep = 0.05,                -- default 0.05 (metres per frame when pushing / pulling)
    RotateStep = 1.5,               -- default 1.5 (degrees per frame when turning)
    Keys = {                        -- control hashes, redm-info Controls.cs
        Confirm = 0x07CE1E61,       -- default Attack (left mouse)
        Cancel = 0xF84FA74F,        -- default Aim (right mouse)
        RotateLeft = 0xA65EBAB4,    -- default FrontendLeft (arrow left)
        RotateRight = 0xDEB34313,   -- default FrontendRight (arrow right)
        Further = 0x6319DB71,       -- default FrontendUp (arrow up)
        Closer = 0x05CA7C52,        -- default FrontendDown (arrow down)
    },
}

---------------------------------
-- what a camp is made of. offset = metres from the tent (x right, y ahead), heading = degrees added
-- to the camp's heading. Every model is from redm-info objects.lua.
---------------------------------
Config.Props = {
    tent     = { model = 'mp005_s_posse_tent_bountyhunter07x', offset = vector3(0.0, 0.0, 0.0),  heading = 0.0 },
    bedroll  = { model = 'p_bedrollopen01x',                    offset = vector3(-2.2, 1.6, 0.0), heading = 90.0 },
    fire     = { model = 'p_campfire01x',                       offset = vector3(0.0, 4.5, 0.0),  heading = 0.0 },
    fireOut  = { model = 'p_campfire01x_nofire',                offset = vector3(0.0, 4.5, 0.0),  heading = 0.0 },
    chest    = { model = 'p_chest01x',                          offset = vector3(2.4, 1.2, 0.0),  heading = 0.0 },
    hitch    = { model = 'p_hitchingpost01x',                   offset = vector3(5.5, -1.0, 0.0), heading = 90.0 },
}
Config.HitchingPost = true          -- default true (a hitching post stands beside every camp)
Config.StreamDistance = 150.0       -- default 150.0 (camp props are made when a player is this close, removed beyond it)
Config.StreamCheckMs = 1500         -- default 1500 (ms between the client's distance checks)
Config.ModelLoadTimeoutMs = 8000    -- default 8000 (give up loading a model after this long)

---------------------------------
-- using a camp
---------------------------------
Config.Interact = 'auto'            -- default 'auto' ('auto' = MULTItarget "Camp" on the tent, bedroll, fire and chest when MULTItarget runs, else the hold-key prompt; 'target'; 'prompt')
Config.TargetIcon = 'fas fa-campground' -- default 'fas fa-campground' (MULTItarget icon)
Config.TargetDistance = 2.5         -- default 2.5 (metres from the camp prop the MULTItarget option shows)
Config.PromptKey = 'J'              -- default 'J' (hold key that opens the camp menu; name from MULTIcore's shared/keybinds.lua)
Config.UseDistance = 3.0            -- default 3.0 (metres from the tent, fire or chest the camp prompt shows)
Config.ServerDistanceCheck = true   -- default true (the server re-checks distance; needs OneSync, which MULTIcore servers run)
Config.ServerUseDistance = 8.0      -- default 8.0 (metres from the camp part the server allows an action)

Config.Fire = {
    StartsLit = true,               -- default true (a new camp's fire burns)
    -- A lit camp fire is a 'campfire' crafting station when MULTIcrafting runs with Config.AllowWorldProps = true
    -- (its own prompt shows at the fire). The camp menu also offers "Cook" when MULTIcrafting is started.
    CookFromMenu = true,            -- default true (the camp menu shows "Cook at the fire" while the fire burns and MULTIcrafting runs)
}

Config.Sleep = {
    Enabled = true,                 -- default true (the tent / bedroll offers "Sleep")
    Ms = 10000,                     -- default 10000 (how long the player lies down)
    Scenario = 'WORLD_HUMAN_SLEEP_GROUND_ARM', -- default (redm-info Scenarios.lua)
    HealthCore = 25,                -- default 25 (added to the health core, 0-100)
    StaminaCore = 25,               -- default 25 (added to the stamina core, 0-100)
    CooldownMinutes = 20,           -- default 20 (minutes before the same character can rest again for the bonus)
    TimeSkipHours = 0,              -- default 0 (hours the player's own clock moves on after sleeping; 0 = off. A time sync script will set it back)
}

Config.Storage = {
    Slots = 20,                     -- default 20 (slots in the camp chest)
    MaxWeight = 60000,              -- default 60000 (grams the camp chest holds)
    PackMovesToSatchel = true,      -- default true (packing up moves chest items into the satchel if they all fit; false = chest must be empty)
}

Config.GangSharing = true           -- default true (an owner may let members of his MULTIcore gang use the chest)

---------------------------------
-- decay: a camp nobody visits is taken down
---------------------------------
Config.Decay = {
    Enabled = true,                 -- default true
    Days = 7,                       -- default 7 (days without the owner coming by before the camp is removed; chest contents are lost)
    VisitRadius = 50.0,             -- default 50.0 (metres from the camp that count as a visit)
    VisitCheckMinutes = 5,          -- default 5 (how often the server looks whether owners are at their camps)
    SweepMinutes = 60,              -- default 60 (how often old camps are removed; also once at start)
}

-- Items MULTIcamps adds to the item registry (only when no script has them yet).
Config.NewItems = {
    tent = {
        name = 'tent', label = 'Camp Tent', weight = 4500, type = 'item',
        image = 'tent.png', unique = false, useable = true, shouldClose = true,
        description = 'A canvas tent with a bedroll and a small chest. Pitch it in the wild', category = 'tools',
    },
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 6,                      -- default 6 (at most this many camp actions ...)
    WindowMs = 3000,                -- default 3000 (... in this many ms, per player)
}
