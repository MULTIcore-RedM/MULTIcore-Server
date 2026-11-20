-- ============================================================
-- MULTIcharacter settings
-- Coordinates marked "RSG v2" come from the RSG v2 framework
-- (GPL v3): rsg-multicharacter (select scene and camera),
-- rsg-spawn (Valentine, Saint Denis) and rsg-medic (the other
-- towns' respawn points). See README.md, Credits.
-- Every text a player sees is in locales/<lang>.lua.
-- ============================================================
Config = {}

-- Language for this script ('en', 'de', 'fr', 'es', 'pt-br', 'it', 'pl', 'ru', 'nl', 'tr'); nil = server.cfg `setr multicore_locale`, else 'en'
Config.Locale = nil

-- Most characters per account (the account's own users.char slot count also applies; the smaller wins)
Config.MaxCharacters = 5

-- ------------------------------------------------------------
-- Select scene: where the preview character stands and the camera
-- that looks at it. Default: the RSG v2 character select platform.
-- ------------------------------------------------------------
Config.Scene = {
    ped = vector4(-558.91, -3776.25, 237.63, 90.0),          -- preview character position and heading (RSG v2 rsg-multicharacter)
    cam = vector3(-562.8157, -3776.266, 239.0805),            -- camera position (RSG v2 rsg-multicharacter)
    camRot = vector3(-4.2146, -0.0007, -87.8802),             -- camera pitch, roll, yaw (RSG v2 rsg-multicharacter)
    camFov = 30.0,                                            -- camera field of view (RSG v2 rsg-multicharacter)
    camRotOrder = 2,                                          -- rotation order passed to SET_CAM_ROT (2 is what most scripts use)
    hidePlayerAt = vector3(-561.0, -3776.25, 237.63),         -- where the hidden, frozen player waits during select
    idleScenario = 'WORLD_HUMAN_STAND_WAITING',               -- idle scenario of the preview character (false = stand still)
    rotateSpeed = 0.4,                                        -- degrees per mouse pixel when dragging the preview character round
    rotateThrottleMs = 30,                                    -- how often the page sends drag turns to the game (ms)
    collisionTimeout = 8000,                                  -- longest wait for the scene's collision before showing it anyway (ms)
}

-- Look for a character with no stored look (made by another creator, or an old row); MULTIcore look format
Config.DefaultLook = {
    male = { skin = { sex = 'male', head = 1, bodyUpper = 1, bodyLower = 1, eyes = 1, teeth = 1, hair = 0, beard = 0, height = 1.0 }, comps = {} },
    female = { skin = { sex = 'female', head = 1, bodyUpper = 1, bodyLower = 1, eyes = 1, teeth = 1, hair = 0, beard = 0, height = 1.0 }, comps = {} },
}

-- ------------------------------------------------------------
-- Spawning
-- ------------------------------------------------------------
-- First spawn of a brand new character (Valentine station, RSG v2 rsg-spawn)
Config.NewPlayerSpawn = vector4(-169.47, 629.38, 114.03, 236.72)

-- RSG v2 scripts that fire rsg-spawn:client:newplayer: true = town picker, false = Config.NewPlayerSpawn straight away
Config.NewPlayerPicker = false

-- Offer the character's last saved position in the spawn picker
Config.AllowLastLocation = true
-- No position is saved within this many metres of the select scene, and an old save there is not
-- offered as "Last location" (stops players spawning in the void under the select platform)
Config.NoSaveRadius = 100.0

-- Towns in the spawn picker. Names and the line under them are locale keys loc_<id> and loc_<id>_desc.
-- Valentine and Saint Denis: RSG v2 rsg-spawn. The rest: RSG v2 rsg-medic respawn points.
Config.SpawnLocations = {
    { id = 'valentine',  coords = vector4(-169.47, 629.38, 114.03, 236.72) },
    { id = 'saintdenis', coords = vector4(2694.69, -1448.48, 46.27, 23.27) },
    { id = 'rhodes',     coords = vector4(1291.85, -1236.22, 80.93, 210.67) },
    { id = 'blackwater', coords = vector4(-733.28, -1242.97, 44.73, 87.64) },
    { id = 'strawberry', coords = vector4(-1801.98, -366.95, 161.66, 236.04) },
    { id = 'annesburg',  coords = vector4(3016.71, 1345.64, 42.69, 67.85) },
    { id = 'vanhorn',    coords = vector4(3033.01, 433.82, 63.81, 65.9) },
    { id = 'armadillo',  coords = vector4(-3613.85, -2640.1, -11.73, 47.92) },
    { id = 'tumbleweed', coords = vector4(-5436.5, -2930.96, 0.69, 182.25) },
}

-- Longest wait for collision at the spawn point before dropping the player in anyway (ms)
Config.SpawnCollisionTimeout = 10000

-- ------------------------------------------------------------
-- Timings (ms)
-- ------------------------------------------------------------
Config.Timing = {
    startDelay = 500,          -- wait after the network session starts before opening select
    pollInterval = 100,        -- how often the start-up checks run while waiting
    modelTimeout = 10000,      -- longest wait for a ped model to load
    fadeOutSelect = 300,       -- fade to black before the select scene is built
    fadeInSelect = 800,        -- fade in on the select scene
    fadeOutCreator = 400,      -- fade to black before the creator opens
    fadeInCreator = 500,       -- fade in after handing over to the creator
    fadeOutSpawn = 500,        -- fade to black before spawning
    fadeInSpawn = 1500,        -- fade in after spawning
    fadeWaitExtra = 2000,      -- extra time allowed for a fade to finish before going on
}

-- ------------------------------------------------------------
-- Logout
-- ------------------------------------------------------------
Config.Logout = {
    command = 'logout',  -- chat command that returns to character select (false = no command)
    ace = false,         -- ACE needed to use it, e.g. 'command.logout' (false = everyone)
    cooldown = 30,       -- seconds between two logouts per player
    allowDead = false,   -- may a dead player log out?
}

-- Notification types (MULTIcore notify types: info, success, error, warning ...)
Config.NotifyError = 'error'      -- type used for failures
Config.NotifySuccess = 'success'  -- type used for confirmations
