-- ============================================================
-- MULTIcore settings (the RSG settings are in config.lua)
-- ============================================================
MULTIConfig = {}

-- Language of every MULTI script (menus, notifications, prompts, the loading screen).
-- One of: en de fr es pt-br it pl ru nl tr ro cs hu uk bg el sv da no fi pt sk hr sr sl zh ja ko ar id vi th
--   en English, de German, fr French, es Spanish, pt-br Portuguese (Brazil), pt Portuguese (Portugal),
--   it Italian, pl Polish, ru Russian, nl Dutch, tr Turkish, ro Romanian, cs Czech, hu Hungarian,
--   uk Ukrainian, bg Bulgarian, el Greek, sv Swedish, da Danish, no Norwegian, fi Finnish, sk Slovak,
--   hr Croatian, sr Serbian (Latin), sl Slovenian, zh Chinese (Simplified), ja Japanese, ko Korean,
--   ar Arabic, id Indonesian, vi Vietnamese, th Thai
-- Default 'en'. '' = use server.cfg  setr multicore_locale <code>  instead.
-- A script can still use its own language with Config.Locale in its config.lua.
MULTIConfig.Language = 'en'

-- Look of every MULTI menu, panel and dialog (one line, no other change needed):
--   'classic'    the base game's black menus with white lettering (default)
--   'parchment'  old paper with dark ink and a brush stroke under the picked row
--   'modern'     a dark card with a silver frame and rounded corners
-- '' = use server.cfg  setr multicore_ui_preset <name>  instead.
MULTIConfig.UIPreset = 'classic'

-- Hide the base game's award / challenge cards on the left of the screen
-- ("Survivalist Award - Hold F1 for details"). false = let the game show them.
MULTIConfig.HideGameAwards = true

-- Stop the base game HUD flashing up when Left Alt (the target key, also the game's
-- "reveal HUD") is pressed. false = let the game reveal its HUD on that key.
MULTIConfig.BlockHudReveal = true

-- How busy the world is: how many people, animals, wagons and coaches the game puts around
-- each player. 1.0 = the game's own amount, 0.5 = half, 0.0 = none (0.0 to 1.0).
-- Fewer can also help slower PCs. Left at 1.0, nothing runs.
-- Other scripts can change them while the server runs: exports.MULTIcore:SetDensity('Peds', 0.3)
MULTIConfig.Density = {
    Peds           = 1.0, -- people walking about in towns and on the roads
    ScenarioPeds   = 1.0, -- people sitting, working, leaning and standing around
    Animals        = 1.0, -- wildlife and town animals (lower values also mean less to hunt)
    Vehicles       = 1.0, -- all wagon and coach traffic (the overall amount)
    RandomVehicles = 1.0, -- wagons and coaches driving the roads
    ParkedVehicles = 1.0, -- wagons standing parked
}

MULTIConfig.Vorp = {
    -- Which player identifier VORP scripts see as user / character "identifier".
    -- 'steam' is what most VORP servers use; players without Steam fall back to 'license'.
    Identifier = 'steam',
    DefaultGroup = 'user',      -- account group for new players
    MaxCharacters = 5,          -- per account (users.char)
    MaxJobs = 3,                -- multi-jobs per account (users.max_jobs)
    DefaultInvCapacity = 200,   -- default 200 (VORP-style item count a character's satchel holds; weapons and ammo don't count)
    SkillLevelXp = 1000,        -- skill experience per level (setSkills)
    -- Where Core.Player.Respawn puts a player when no spot is given: the nearest of these.
    RespawnPoints = {
        vector4(-169.47, 629.38, 114.03, 236.72),    -- Valentine
        vector4(2694.69, -1448.48, 46.27, 23.27),    -- Saint Denis
        vector4(1291.85, -1236.22, 80.93, 210.67),   -- Rhodes
        vector4(-733.28, -1242.97, 44.73, 87.64),    -- Blackwater
        vector4(-1801.98, -366.95, 161.66, 236.04),  -- Strawberry
        vector4(3016.71, 1345.64, 42.69, 67.85),     -- Annesburg
        vector4(3033.01, 433.82, 63.81, 65.9),       -- Van Horn
        vector4(-3613.85, -2640.1, -11.73, 47.92),   -- Armadillo
        vector4(-5436.5, -2930.96, 0.69, 182.25),    -- Tumbleweed
    },
    -- When an account's group is one of these, the player also gets the matching
    -- ACE principal, so RSG permission checks (HasPermission 'admin') agree with VORP's group.
    GroupPrincipals = { admin = 'group.admin', superadmin = 'group.admin', mod = 'group.mod' },
}

-- Gold and role tokens may have cents (VORP stores them with 2 decimals).
MULTIConfig.DecimalCurrencies = { cash = true, bank = true, gold = true, rol = true }


-- Looks made by MULTIcore's own creator (format 'multi')
MULTIConfig.Look = {
    MinHeight = 0.9,            -- smallest character scale the creator allows
    MaxHeight = 1.1,            -- largest character scale
    DefaultBirthdate = '1870-01-01',
    DefaultNationality = 'American',
    ReadyTimeoutMs = 3000,      -- longest wait (ms) for body and clothing pieces to stream in
    CompReadyTimeoutMs = 2000,  -- same, after a single clothing piece
    TextureTimeoutMs = 3000,    -- longest wait for a face overlay texture
    ModelTimeoutMs = 10000,     -- longest wait for mp_male / mp_female to load
    RespawnDelayMs = 1500,      -- wait after a respawn / revive before re-dressing the character
    TextureCleanupMs = 10000,   -- how often overlay textures of removed peds are given back
}
-- When no spawn script (MULTIcharacter) runs, RSG's player-loaded events fire this long after a character is selected.
MULTIConfig.SpawnFallbackMs = 2000

-- Tables that scripts read and write with SQL directly (server/multi/compat_*.lua, docs/COMPAT_SURVEY.md)
MULTIConfig.Compat = {
    CharactersTable = true,     -- keep VORP's `characters` table in step with every character (false = leave it alone)
    CharactersSyncSeconds = 60, -- how often online characters pick up script writes to characters.money/gold/rol/job (0 = only on login and save)
    CharactersBackfill = true,  -- on start, write a `characters` row for every character that has none yet (offline pay-outs need one)
    PlayerskinsMirror = true,   -- keep an RSG `playerskins` row per character, filled from the MULTIcore look (best effort)
    VorpSetJobEvent = true,     -- send the client event vorp:setjob (job, grade) when a character's job or grade changes
}

MULTIConfig.Debug = false

-- Wages. Business jobs are paid from their own bank account (RSGConfig.Money.PayCheckSociety in config.lua).
-- These job types / jobs are paid straight by the server instead, with no account: law, medical, justice.
MULTIConfig.ServerPaid = {
    Types = { leo = true, medic = true, doj = true },
    Jobs = {},          -- extra job names, e.g. { telegraph = true }
}

-- How often the owning client reports its real coordinates to the server, so "last location"
-- keeps advancing even when the server cannot read the remote ped at save time.
MULTIConfig.PositionSyncMs = 5000
