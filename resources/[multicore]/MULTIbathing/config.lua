-- ============================================================
-- MULTIbathing settings
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- Every line a player sees is in locales/<lang>.lua.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = MULTIcore's language (MULTIConfig.Language), else English)
Config.Debug  = false               -- default false (extra prints in F8 / the server console)

---------------------------------
-- prices
---------------------------------
Config.Currency         = 'cash'    -- default 'cash' (money type players pay with)
Config.NormalBathPrice  = 1         -- default 1 (a bath)
Config.DeluxeBathPrice  = 5         -- default 5 (the luxury service, paid on top while in the bath)
Config.Cleanliness      = 100       -- default 100 (cleanliness after a bath, 0-100; MULTIhud need)

---------------------------------
-- interaction (MULTItarget, hold Left Alt)
---------------------------------
Config.Interact       = 'auto'      -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target'; 'prompt')
Config.Key            = 'J'         -- default 'J' (prompt key at the bath house counter; prompt mode only)
Config.TargetRadius   = 1.0         -- default 1.0 (size of the MULTItarget point at the counter)
Config.TargetDistance = 2.0         -- default 2.0 (how close to stand for MULTItarget)
Config.PromptDistance = 1.5         -- default 1.5 (metres at which a prompt shows; prompt mode)
Config.ServerDistance = 6.0         -- default 6.0 (the server refuses a bath farther than this from the counter)

---------------------------------
-- blips and doors
---------------------------------
Config.ShowBlips = true             -- default true (bath house blips on the map)
Config.LockDoors = true             -- default true (keep the bath room doors shut; the bathing scene opens them)

---------------------------------
-- bath houses
-- dict     : the game's bathing scene for that bath house (do not change)
-- rag      : where the wash rag goes
-- consumer : the counter point where a bath is bought
-- lady/guy : who gives the luxury service (lady for male characters, guy for female ones)
-- door     : the bath room door hash
---------------------------------
Config.BathingZones = {
    ['SaintDenis'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_ST_DENIS',
        rag = vector4(2629.4, -1223.33, 58.57, -92.66),
        consumer = vector3(2632.6, -1223.79, 59.59),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = 779421929,
    },
    ['Valentine'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_VALENTINE',
        rag = vector4(-317.37, 761.8, 116.44, 10.365),
        consumer = vector3(-320.56, 762.41, 117.44),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = 142240370,
    },
    ['Annesburg'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_ANNESBURG',
        rag = vector4(2952.65, 1334.7, 43.44, -291.27),
        consumer = vector3(2950.42, 1332.15, 44.44),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = -201071322,
    },
    ['Strawberry'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_STRAWBERRY',
        rag = vector4(-1812.83, -373.23, 165.5, 1.206),
        consumer = vector3(-1816.45, -372.44, 166.50),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = 1256786197,
    },
    ['Blackwater'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_BLACKWATER',
        rag = vector4(-823.86, -1318.84, 42.68, -0.459),
        consumer = vector3(-822.82, -1315.72, 43.58),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = 1523300673,
    },
    ['Vanhorn'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_VANHORN',
        rag = vector4(2987.62, 573.21, 46.86, 83.841),
        consumer = vector3(2986.31, 568.27, 47.85),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = 1102743282,
    },
    ['Rhodes'] = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_RHODES',
        rag = vector4(1336.85, -1378.04, 83.2897, 166.469),
        consumer = vector3(1340.11, -1379.6, 84.28),
        lady = `CS_BATHINGLADIES_01`, guy = `CS_LeviSimon`,
        door = -1847993131,
    },
}

---------------------------------
-- scrubbing order (the luxury service scrubs the parts marked deluxe)
---------------------------------
Config.BathingModes = {
    { transition = 'Scrub_Head',      scrub_freq = 0.75 },
    { transition = 'Scrub_Left_Arm',  scrub_freq = 0.7, deluxe = true },
    { transition = 'Scrub_Right_Arm', scrub_freq = 0.5, deluxe = true },
    { transition = 'Scrub_Right_Leg', scrub_freq = 0.6, deluxe = true },
    { transition = 'Scrub_Left_Leg',  scrub_freq = 0.7, deluxe = true },
}
