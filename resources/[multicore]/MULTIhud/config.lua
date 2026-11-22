-- MULTIhud configuration. Every option is commented.
-- Needs are stored in the RSGCore player metadata on a 0-100 scale:
--   hunger, thirst, cleanliness (100 = full / clean), stress (0 = calm).

Config = {}

Config.Locale = nil                -- language for this script ('en', 'de', ...); nil = MULTIcore's language (MULTIConfig.Language), else 'en'
Config.Debug = false               -- print needs changes to the server console

---------------------------------------------------------------------------
-- Needs (server side)
---------------------------------------------------------------------------
Config.TickSeconds = 30            -- how often the server applies decay to every logged-in player

-- how much each need drops per real minute while standing / walking (0 = off)
Config.Decay = {
    hunger = 0.50,                 -- 100 -> 0 in about 3h 20m
    thirst = 0.70,                 -- 100 -> 0 in about 2h 20m
    cleanliness = 0.20,            -- 100 -> 0 in about 8h
}

-- decay is multiplied by this while the player is running, sprinting or swimming
-- (the client reports what the player is doing, at most once every Config.ReportMinSeconds)
Config.ActivityMultiplier = {
    idle = 1.0,
    run = 1.5,
    sprint = 2.5,
    swim = 2.0,
}
-- which needs the activity multiplier applies to
Config.ActivityAffects = { hunger = true, thirst = true, cleanliness = true }
Config.ReportMinSeconds = 5        -- the client sends at most one activity report per this many seconds

-- value a need starts at if the character has none stored yet
Config.Defaults = { hunger = 100, thirst = 100, cleanliness = 100, stress = 0 }

Config.SkipDead = true             -- no decay while metadata.isdead is set (rsg-medic and the like)

-- What happens when hunger or thirst reaches 0 (applied on the player's own client)
Config.Starving = {
    Enabled = true,
    IntervalSeconds = 10,          -- how often damage is applied while starving / dehydrated
    HungerDamage = 4,              -- health lost per interval at 0 hunger
    ThirstDamage = 6,              -- health lost per interval at 0 thirst
    InnerCoreDrain = 5,            -- also drain the health core (0-100) by this much per interval (0 = off)
    CanKill = true,                -- false: health never goes below MinHealth from starving
    MinHealth = 1,                 -- lowest health starving can leave when CanKill = false
    Notify = true,                 -- tell the player (MULTIcore notification) when they start starving / dehydrating
}

-- Client writes (food / drink scripts on the player's PC change needs through the server)
Config.ClientWrites = {
    PerSecond = 10,                -- most need changes one player may send per second; more are ignored
    StressFloodMs = 200,           -- hud:server:GainStress / RelieveStress accepted at most this often per player
    MaxStressStep = 100,           -- largest stress change one GainStress / RelieveStress may make
}

-- Stress (0 = calm, 100 = maximum)
Config.Stress = {
    FromShooting = true,           -- firing a weapon raises stress
    PerShot = 1.0,                 -- stress added per accepted shot report
    ShotCooldownMs = 1500,         -- the client reports shooting at most this often (the server enforces it too)
    ExemptJobs = {                 -- these jobs get no stress from shooting (job names from shared/jobs.lua)
        vallaw = true, rholaw = true, blklaw = true, strlaw = true, stdenlaw = true,
    },
    RecoveryPerMinute = 1.0,       -- stress drops by this per minute when the player has not fired for a while
    RecoveryDelaySeconds = 120,    -- seconds after the last shot before stress starts dropping
}

---------------------------------------------------------------------------
-- Temperature (world temperature at the player's position)
---------------------------------------------------------------------------
Config.Temperature = {
    Enabled = true,
    Unit = 'auto',                 -- 'auto' (the game's own metric setting), 'C' or 'F'
    Cold = 0,                      -- at or below this many degrees C the player counts as cold
    Hot = 32,                      -- at or above this many degrees C the player counts as hot
    ColdHungerMultiplier = 1.5,    -- hunger decays this much faster while cold (1.0 = no effect)
    HotThirstMultiplier = 1.5,     -- thirst decays this much faster while hot (1.0 = no effect)
    ReadMs = 3000,                 -- how often the client reads the temperature (it changes slowly)
}

---------------------------------------------------------------------------
-- HUD (client side)
---------------------------------------------------------------------------
-- Hide the game's own small core icons (health, stamina, dead eye, horse) next to the radar, so they don't sit on top
-- of MULTIhud's rings. false = leave the game's icons as they are.
Config.HideGameCores = true

-- Hide the game's own cash, gold and token display (top right) and its honor bar (bottom left).
-- The game shows them when its "Reveal HUD" key is pressed, which is Left Alt, the same key as targeting.
-- false = the game shows them as normal.
Config.HideGameMoneyHonor = true

Config.Hud = {
    Command = 'hud',               -- /hud toggles the HUD for the player (remembered on their PC)
    Style = 'ring',                -- 'ring' (round gauges) or 'bar' (thin bars with labels)
    Position = 'bottom-center',    -- 'bottom-center' (across the middle of the bottom edge), 'top-center',
                                   -- 'bottom-left', 'bottom-right', 'top-left', 'top-right'
    OffsetX = 2.0,                 -- distance from the side, in % of the screen width (not used by the -center positions)
    OffsetY = 2.5,                 -- distance from the top / bottom, in % of the screen height
                                   -- (for 'bottom-left' use about 25 so it sits above the game's radar)
    Scale = 1.0,                   -- size of the whole HUD (1 = normal)
    -- Players can move and resize their own HUD: /hudedit, then drag it with the mouse, mouse wheel = size,
    -- Save / Reset / Cancel buttons (or Enter / R / Esc). Saved on the player's own PC; /hudreset puts it back.
    EditCommand = 'hudedit',       -- false = players can't move their HUD
    ResetCommand = 'hudreset',
    MinScale = 0.5,                -- smallest size a player may set
    MaxScale = 2.0,                -- largest size a player may set
    ShowNumbers = true,            -- show the value inside each gauge
    LowWarning = 20,               -- a gauge at or below this % turns red
    UpdateMs = 300,                -- how often the HUD reads the game (lower = smoother, more CPU)
    ActivityCheckMs = 1000,        -- how often the client checks running / sprinting / swimming
    VoiceCheckMs = 5000,           -- how often the client checks whether MULTIvoice / pma-voice is running
    NotifyToggle = true,           -- show a notification when /hud hides or shows the HUD
    GaugeSize = 40,                -- ring diameter in pixels (bars scale with it)
    Gap = 5,                       -- space between gauges in pixels

    -- gauge colours (any CSS colour); restyle further in html/custom.css
    Colors = {
        health = '#ffffff',        -- white rings, like the game's own cores
        stamina = '#ffffff',
        hunger = '#ffffff',
        thirst = '#ffffff',
        stress = '#ffffff',
        cleanliness = '#ffffff',
        temperature = '#ffffff',   -- mild
        cold = '#9cc4e4',          -- temperature at or below Config.Temperature.Cold
        hot = '#e08a4a',           -- temperature at or above Config.Temperature.Hot
        horseHealth = '#ffffff',
        horseStamina = '#ffffff',
        voice = 'rgba(255,255,255,0.35)', -- not talking
        talking = '#ffffff',       -- talking
        radio = '#d6b25e',         -- talking on the radio
        low = '#c0281e',           -- any gauge at or below LowWarning (game red)
    },

    -- which gauges show (order on screen follows Config.Hud.Order)
    Show = {
        health = true,
        stamina = true,
        hunger = true,
        thirst = true,
        stress = true,
        cleanliness = true,
        temperature = true,
        horse = true,              -- horse health and stamina while mounted
        voice = true,              -- only when MULTIvoice (or pma-voice) is running
    },
    Order = { 'health', 'stamina', 'hunger', 'thirst', 'stress', 'cleanliness', 'temperature' },
    -- the text under each gauge is in locales/<lang>.lua
}

-- Money panel: cash, gold, bank
Config.Money = {
    Mode = 'key',                  -- 'always', 'key' (while the game's "reveal HUD" control is held) or 'off'
    Key = 0xCF8A4ECA,              -- control hash: RevealHud (redm-info Controls.cs)
    ShowSeconds = 5,               -- how long the panel stays after the key is let go / money changes
    ShowOnChange = true,           -- show the panel briefly whenever money changes
    ShowGold = true,
    ShowBank = true,
    ShowBloodmoney = false,
}

---------------------------------------------------------------------------
-- Compatibility
---------------------------------------------------------------------------
-- vorp_metabolism stand-in: VORP uses 0-1000 for Hunger and Thirst; MULTIcore stores 0-100.
Config.Vorp = {
    Enabled = true,
    Scale = 10,                    -- VORP value / Scale = MULTIcore value (1000 -> 100)
}
-- rsg-hud events (hud:client:UpdateHunger, hud:server:GainStress, ...)
Config.Rsg = {
    Enabled = true,
}
