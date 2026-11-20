-- ============================================================
-- MULTImedic settings
-- Hospital / doctor coordinates come from the rsg-medic config of the
-- RSG v2 framework (GPL v3, credited in README).
-- ============================================================
Config = {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = server-wide setr multicore_locale, else English
Config.Debug = false                -- prints deaths, revives, respawns and ignored rsg-medic events to the console

---------------------------------
-- who counts as a medic
---------------------------------
Config.MedicJobs = {                -- job names (MULTIcore shared/jobs.lua) that may revive and treat, and get doctor calls
    medic = true,
}
Config.RequireOnDuty = true         -- true = only medics on duty can revive / treat and get doctor calls
Config.AdminPermissions = { 'admin', 'god' } -- RSGCore permission groups that count as admin (commands, trusted rsg-medic events)

-- The server re-checks distances between players (needs OneSync, which MULTIcore servers run).
-- Set to false only if OneSync is off.
Config.ServerDistanceCheck = true

---------------------------------
-- death screen
---------------------------------
Config.RespawnTimer = 300           -- seconds a player must stay down before "Hold E to respawn" shows (rsg-medic default 300)
Config.HoldSeconds = 3              -- how long E must be held to respawn (seconds)
Config.RespawnKey = 'E'             -- key name from MULTIcore's shared/keybinds.lua: hold to respawn
Config.CallKey = 'G'                -- key name from MULTIcore's shared/keybinds.lua: call for a doctor
Config.DeathCheckMs = 500           -- how often the client checks whether the player has died (ms)
Config.KeepDeadOnRelog = true       -- a player who logs out while dead comes back down (stops "combat logging" out of death)
Config.RelogDelayMs = 3000          -- wait after the character spawns before putting a relogged dead player back down (ms)
Config.DisableAutoSpawn = true      -- turn off cfx spawnmanager's auto respawn (if spawnmanager runs) so the player stays down
Config.PauseDeathRestart = true     -- also call the game's PAUSE_DEATH_ARREST_RESTART (story-mode death restart) -- effect in multiplayer UNVERIFIED
Config.Screen = {
    Cursor = false,                 -- true = show the mouse so the "call for a doctor" button can be clicked (the key works either way)
    ShowFee = true,                 -- show the doctor's fee on the death screen
    ShowMedicCount = true,          -- show how many doctors are on duty
}

---------------------------------
-- calling a doctor
---------------------------------
Config.Call = {
    Enabled = true,                 -- false = no "call for a doctor" button
    Cooldown = 60,                  -- seconds between two calls from the same player (checked on the server too)
    BlipSeconds = 180,              -- how long the call blip stays on the doctors' maps
    ArriveDistance = 5.0,           -- the blip and route are removed once the doctor is this close (metres)
    GpsRoute = true,                -- draw a GPS route to the call
    GpsColor = 'COLOR_GREEN',       -- GPS route colour name (value rsg-medic uses) -- UNVERIFIED (not in femga natives.json)
    BlipStyle = 1664425300,         -- BlipAddForCoords style hash (value rsg-medic uses) -- UNVERIFIED (not in femga natives.json)
    BlipSprite = 1109348405,        -- blip sprite hash (value rsg-medic uses) -- UNVERIFIED
    BlipScale = 0.8,                -- blip size
    BlipModifier = 'BLIP_MODIFIER_AREA_PULSE', -- pulsing blip (name rsg-medic uses) -- UNVERIFIED; '' = none
    MaxTextLength = 120,            -- longest message accepted from rsg-medic:server:medicAlert (other scripts' alerts)
}

---------------------------------
-- respawn at the doctor
---------------------------------
Config.Respawn = {
    Fee = 5,                        -- doctor's fee in dollars taken on respawn (0 = free)
    FeeFromBank = true,             -- if cash is short, take the rest from the bank account
    LoseCash = false,               -- true = all cash is lost on respawn (after the fee)
    LoseBloodmoney = false,         -- true = blood money is lost on respawn (only if the money type exists)
    LoseItems = false,              -- true = everything in the satchel is lost on respawn (after the fee)
    KeepItems = {},                 -- item names a player keeps even when LoseItems = true, e.g. { 'bible', 'horse_brush' }
    LoseWeapons = false,            -- true = weapons in hand are taken off the ped on respawn (client side only)
    HealthPercent = 20,             -- health after a respawn, in percent of max (rsg-medic default 20)
    ResetNeeds = true,              -- refill hunger / thirst and clear stress through MULTIhud (if it runs)
    Needs = { hunger = 100, thirst = 100, cleanliness = 100, stress = 0 }, -- values ResetNeeds writes
    ResetOutlawStatus = true,       -- fire rsg-prison:server:resetoutlawstatus (as rsg-medic does); harmless if nothing listens
    UseCoreRespawn = false,         -- true = let MULTIcore's Core.Player.Respawn(src, coords) do the move (the core supports coords now; README
                                    -- to accept the hospital coords; without it the core picks its own town); false = MULTImedic moves the player
    ReloadLook = true,              -- re-dress the character after an own respawn (MULTIcore's look library)
    FadeMs = 500,                   -- screen fade out / in time (ms)
    Locations = {                   -- nearest one is used; coords from rsg-medic's Config.RespawnLocations (RSG v2, GPL v3)
        { label = 'place_valentine',  coords = vector4(-242.69, 796.27, 121.16, 110.18) },
        { label = 'place_blackwater', coords = vector4(-733.28, -1242.97, 44.73, 87.64) },
        { label = 'place_strawberry', coords = vector4(-1801.98, -366.95, 161.66, 236.04) },
        { label = 'place_armadillo',  coords = vector4(-3613.85, -2640.1, -11.73, 47.92) },
        { label = 'place_tumbleweed', coords = vector4(-5436.5, -2930.96, 0.69, 182.25) },
        { label = 'place_saintdenis', coords = vector4(2725.33, -1067.42, 47.4, 168.42) },
        { label = 'place_rhodes',     coords = vector4(1291.85, -1236.22, 80.93, 210.67) },
        { label = 'place_vanhorn',    coords = vector4(3033.01, 433.82, 63.81, 65.9) },
        { label = 'place_annesburg',  coords = vector4(3016.71, 1345.64, 42.69, 67.85) },
    },
}

---------------------------------
-- revive and treat by medics
---------------------------------
Config.Revive = {
    Time = 5000,                    -- how long a medic revive takes (ms)
    HealthPercent = 60,             -- patient health after a medic revive, in percent of max (rsg-medic default 60)
    MaxDistance = 3.0,              -- how close the medic must be to the patient (metres, checked on the server)
    MinTimeFactor = 0.8,            -- the server refuses a revive finished faster than Time * this
    Scenario = 'WORLD_HUMAN_CROUCH_INSPECT', -- scenario the medic plays (redm-info Scenarios.lua)
    Item = 'firstaid',              -- item a medic uses up per revive (doctor's stores sell it)
    RequireItem = true,             -- true = the medic must carry Item; one is used up per revive
    Command = 'medrevive',          -- medic command: revive the nearest downed player ('' = off). MULTItarget works too.
}
Config.Treat = {
    Time = 5000,                    -- how long treating wounds takes (ms)
    HealthPercent = 30,             -- health added to the patient, in percent of max (rsg-medic default 30)
    Item = 'bandage',               -- item a medic uses up per treatment
    RequireItem = true,             -- true = the medic must carry Item; one is used up per treatment
    Command = 'medtreat',           -- medic command: treat the nearest player ('' = off)
}
---------------------------------
-- medical items a player uses on themselves (from the satchel)
-- health = % of max health added, improve = how many injury steps get better (worst wound first),
-- time = how long the bandaging takes (ms). The item is only taken when the bandaging finishes.
-- Another script that makes one of these items usable takes it over.
---------------------------------
Config.SelfCare = {
    Enabled = true,
    Items = {
        bandage      = { health = 15, improve = 1, time = 6000 },   -- rsg-medic: 15 %
        fieldbandage = { health = 25, improve = 2, time = 8000 },
        firstaid     = { health = 50, improve = 3, time = 10000 },
    },
    AllowOnMount = false,           -- false = get off the horse first
    -- bandaging animation used by rsg-medic (RSG v2, GPL v3); not listed in redm-info, works in rsg-medic
    Anim = { dict = 'mini_games@story@mob4@heal_jules@bandage@arthur', clip = 'bandage_fast', flag = 1 },
}

Config.Target = {
    Enabled = true,                 -- add "Revive" / "Treat wounds" to every player through MULTItarget (if it runs)
    Distance = 2.5,                 -- MULTItarget reach
    ReviveIcon = 'fa-solid fa-kit-medical', -- Font Awesome icon of "Revive"
    TreatIcon = 'fa-solid fa-bandage', -- Font Awesome icon of "Treat wounds"
}

---------------------------------
-- admin commands (rsg-medic had these)
---------------------------------
Config.Commands = {
    Revive = 'revive',              -- /revive [id]  revive yourself or a player ('' = off)
    Heal = 'heal',                  -- /heal [id]    heal yourself or a player ('' = off)
    Kill = 'kill',                  -- /kill id      kill a player ('' = off)
    Permission = 'admin',           -- RSGCore permission for these commands
}

---------------------------------
-- rsg-medic compatibility
---------------------------------
Config.Compat = {
    -- rsg-medic:client:adminRevive / playerRevive / adminHeal are client events other scripts
    -- (rsg-adminmenu ...) fire. The server cannot tell who fired them, so:
    -- true  = accept them (like rsg-medic; a cheater could resurrect locally anyway),
    -- false = only accept them from admins (Config.AdminPermissions).
    TrustClientRevive = true,
    DeathLog = true,                -- send a 'death' log to rsg-log:server:CreateLog (ignored if nothing listens)
    -- VORP scripts send vorp_core:Client:AddTimeToRespawn (seconds) to a downed player (a doctor is coming).
    -- MULTImedic adds that to the respawn timer of the current death. Most seconds added per death (0 = no cap).
    MaxAddRespawnSeconds = 900,
}

---------------------------------
-- simple injuries (optional)
---------------------------------
Config.Injuries = {
    Enabled = false,                -- true = body hits can cause limping and bleeding
    DamageThreshold = 20,           -- health lost at once before a hit counts (rsg-medic default 20)
    HitCooldown = 5,                -- seconds between two counted hits (checked on the server)
    Chance = {                      -- chance a counted hit makes a part worse
        injured = 0.5,              -- healthy -> injured
        broken = 0.35,              -- injured -> broken
        bleeding = 0.2,             -- broken -> bleeding
    },
    DeathInjuries = true,           -- give random injuries on death (cleared by respawn or a medic revive)
    LimpOnLegs = true,              -- an injured / broken leg makes the player walk only
    LimpMaxMoveBlend = 1.0,         -- top move speed while limping (1 = walk, 2 = run, 3 = sprint)
    BleedDamage = 5,                -- health lost per bleed tick
    BleedInterval = 10,             -- seconds between bleed ticks
    Parts = { 'head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }, -- rsg-medic body part names
}
