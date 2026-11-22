-- ============================================================
-- MULTIconsumables settings (part of MULTIcore by RINGO (RINGOscripting), GPL v3)
-- What each item does is in config/consumables.lua, the animations and props
-- in config/anims.lua, the items this resource adds in config/items.lua.
-- Needs (hunger, thirst, stress) are 0-100 like MULTIhud / RSG: 100 hunger = full,
-- 100 stress = very stressed. Times are real seconds unless the name says Ms.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = MULTIcore's language (MULTIConfig.Language), else English)
Config.Debug = false                -- default false (prints every use, drunk change and addiction change to the server console)

---------------------------------
-- using an item
---------------------------------
Config.Use = {
    ApplyOnStart = true,            -- default true (effects apply as soon as the use starts; false = only when the animation finishes)
                                    -- The item is always taken when the use starts; stopping early never gives it back.
    CancelKey = 'X',                -- default 'X' (key name from MULTIcore's shared/keybinds.lua that stops eating / drinking / smoking early)
    CooldownMs = 1000,              -- default 1000 (gap after one use ends before the next can start)
    MaxAnimMs = 30000,              -- default 30000 (server gives up waiting for a client's "finished" after this long)
    Unarm = true,                   -- default true (put the weapon away before eating or drinking)
    AllowOnMount = true,            -- default true (eat and drink in the saddle; smoking and chewing play no animation there)
    AllowInWater = false,           -- default false (no eating or drinking while swimming)
    BlockWhenDead = true,           -- default true (nothing can be used while dead or down)
    FinishTimeoutMs = 2000,         -- default 2000 (extra time allowed for the client's "finished" message to arrive)
}

---------------------------------
-- drunk system (per character, kept in the metadata as 'multi_drunk')
---------------------------------
Config.Drunk = {
    Enabled = true,                 -- default true
    Max = 100,                      -- default 100 (highest drunk level)
    TickSeconds = 30,               -- default 30 (how often the level goes down)
    DecayPerMinute = 1.5,           -- default 1.5 (drunk points lost per minute; 30 points take 20 minutes)
    OfflineDecay = true,            -- default true (time spent logged out sobers too)
    ToleranceReduces = true,        -- default true (a heavy drinker gets less drunk from the same drink, see Config.Addiction)

    -- effects by level: the highest level whose `min` is reached applies
    --   drunkness   game drunk walk and sway, _SET_PED_DRUNKNESS 0.0-1.0 (natives.json: 0.25 slightly, 0.5 moderately, 1.0 very)
    --   postfx      screen effect (ANIMPOSTFX_PLAY name, see README for where each name was seen)
    --   camShake    DRUNK_SHAKE camera sway intensity (0 = none)
    --   aimShake    HAND_SHAKE intensity while aiming (0 = none)
    --   noLockon    true = no aim lock-on (slower, harder aiming)
    --   stumble     % chance per check to stumble and fall while walking or running (0 = never)
    Levels = {
        { min = 10, key = 'tipsy',      drunkness = 0.25, postfx = 'PlayerDrunk01',      camShake = 0.0,  aimShake = 0.1, noLockon = false, stumble = 0 },
        { min = 30, key = 'drunk',      drunkness = 0.5,  postfx = 'PlayerDrunk01',      camShake = 0.15, aimShake = 0.3, noLockon = false, stumble = 0 },
        { min = 55, key = 'very_drunk', drunkness = 1.0,  postfx = 'PlayerDrunkSaloon1', camShake = 0.3,  aimShake = 0.5, noLockon = true,  stumble = 4 },
        { min = 75, key = 'wasted',     drunkness = 1.0,  postfx = 'PlayerDrunkSaloon1', camShake = 0.5,  aimShake = 0.8, noLockon = true,  stumble = 10 },
    },
    StumbleCheckSeconds = 6,        -- default 6 (how often a stumble is rolled while moving on foot)
    StumbleMinSpeed = 1.2,          -- default 1.2 (metres per second; standing players never stumble)
    StumbleRagdollMs = { 1200, 2500 }, -- default { 1200, 2500 } (how long a stumble keeps the player down, min / max)
    CamShakeName = 'DRUNK_SHAKE',   -- default 'DRUNK_SHAKE' (natives.json lists it as a confirmed shake name)
    AimShakeName = 'HAND_SHAKE',    -- default 'HAND_SHAKE' (natives.json lists it as a confirmed shake name)
    NotifyLevels = true,            -- default true (a notification when the player gets tipsy, drunk, very drunk ... and sober again)

    -- blackout at the top
    Blackout = {
        Enabled = true,             -- default true
        At = 95,                    -- default 95 (drunk level that knocks the player out)
        Vomit = true,               -- default true (throw up before passing out)
        VomitDict = 'amb_misc@world_human_vomit@male_a@idle_b', -- default (rsg-consume; dict in redm-info animations.lua)
        VomitClip = 'idle_f',       -- default 'idle_f' (rsg-consume)
        VomitMs = 6000,             -- default 6000
        SleepDict = 'amb_rest@world_human_sleep_ground@arm@male_b@idle_b', -- default (rsg-consume; dict in redm-info animations.lua)
        SleepClip = 'idle_f',       -- default 'idle_f' (rsg-consume)
        FadeOutMs = 3000,           -- default 3000 (screen fades to black)
        BlackSeconds = 20,          -- default 20 (how long the screen stays black: "you wake up later")
        FadeInMs = 4000,            -- default 4000
        PassOutFx = 'PlayerDrunk01_PassOut', -- default (rsg-consume)
        WakeFx = 'PlayerWakeUpDrunk',  -- default (rsg-consume)
        WakeFxMs = 8000,            -- default 8000 (how long the wake-up effect plays)
        WakeLevel = 45,             -- default 45 (drunk level after waking up)
        Hangover = { hunger = -10, thirst = -20, stress = 10 }, -- default (needs change on waking; negative = lower)
        SafetySeconds = 90,         -- default 90 (server wakes the player itself if the client never reports back)
    },
}

---------------------------------
-- addiction (per character and substance, kept in the metadata as 'multi_addiction')
-- level 0-100 rises with each use. At `addictedAt` or more the character is addicted:
--   after `cravingAfter` seconds without it: craving messages now and then;
--   after `withdrawalAfter` seconds: withdrawal (stress up, cores drained, shaky hands, notifications);
--   after `recoverAfter` seconds clean the level drops by `recoverPerHour` each hour (logged out too),
--   and below `addictedAt` the habit is broken.
-- tolerance: at level 100 the item's good effects (stress relief, healing, stamina, drunkenness for
--   alcohol) are cut by this share (0.5 = halved); in between it scales with the level.
---------------------------------
Config.Addiction = {
    Enabled = true,                 -- default true
    TickSeconds = 60,               -- default 60 (how often cravings, withdrawal and recovery are checked)
    NotifyEveryTicks = 5,           -- default 5 (withdrawal message every this many ticks; cravings are random)
    Substances = {
        alcohol = {
            gainPerUse = 3,         -- default 3 (level added per drink; an item may set its own `addiction`)
            addictedAt = 40,        -- default 40
            cravingAfter = 1800,    -- default 1800 (30 minutes)
            withdrawalAfter = 5400, -- default 5400 (90 minutes)
            recoverAfter = 21600,   -- default 21600 (6 hours clean before the level falls)
            recoverPerHour = 4,     -- default 4
            tolerance = 0.5,        -- default 0.5
            cravingChance = 25,     -- default 25 (% chance per tick of a craving message)
            withdrawal = { stress = 2, healthCore = -2, staminaCore = -3, shake = 0.35, postfx = 'PlayerHealthPoorCS' },
        },
        tobacco = {
            gainPerUse = 4, addictedAt = 35, cravingAfter = 1200, withdrawalAfter = 3600,
            recoverAfter = 14400, recoverPerHour = 5, tolerance = 0.4, cravingChance = 30,
            withdrawal = { stress = 3, healthCore = 0, staminaCore = -2, shake = 0.15, postfx = false },
        },
        laudanum = {
            gainPerUse = 8, addictedAt = 30, cravingAfter = 1800, withdrawalAfter = 5400,
            recoverAfter = 43200, recoverPerHour = 3, tolerance = 0.6, cravingChance = 35,
            withdrawal = { stress = 4, healthCore = -4, staminaCore = -4, shake = 0.5, postfx = 'PlayerHealthPoorCS' },
        },
    },
    -- withdrawal effect names: `stress` is added each tick (MULTIhud), `healthCore` / `staminaCore` are added
    -- to the game's inner cores (0-100) each tick, `shake` is HAND_SHAKE while aiming, `postfx` a screen effect
    -- that plays while in withdrawal (false = none).
}
