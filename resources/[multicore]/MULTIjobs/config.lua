-- ============================================================
-- MULTIjobs settings
-- Jobs and gangs themselves (names, grades, pay) live in MULTIcore's
-- shared/jobs.lua and shared/gangs.lua. This file says which jobs the
-- job centre offers, where the job centres, boss desks and duty points
-- are, and the limits for bosses.
-- Boss desk and duty coordinates come from the rsg-bossmenu, rsg-lawman
-- and rsg-medic configs of the RSG v2 framework (GPL v3, see README).
-- ============================================================
Config = {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = server-wide setr multicore_locale, else English
Config.Debug = false                -- prints every job / boss / gang action to the server console
Config.NotifyDuration = 5000        -- how long notifications stay on screen (ms)
Config.CheckIntervalMs = 1000       -- how often the client checks NPC distance and walking away from an open menu (ms)

---------------------------------
-- how players open things
---------------------------------
Config.Interact = 'auto'            -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget sphere on each point (and the clerk), 'prompt' = hold-key prompt at each point
Config.PromptKey = 'J'              -- key name from MULTIcore's shared/keybinds.lua (prompt mode only)
Config.PromptDistance = 2.5         -- how close the player must stand for a prompt to show (prompt mode only, metres; job centre points sit on the clerk)
Config.TargetIcons = {              -- MULTItarget icons (Font Awesome)
    centre = 'fas fa-briefcase',    -- job centre
    boss = 'fas fa-user-tie',       -- boss desk
    duty = 'fas fa-clipboard-check', -- duty point
    gang = 'fas fa-users',          -- gang point
}
Config.TargetRadius = 1.2           -- size of the MULTItarget sphere (target mode only)
Config.TargetDistance = 2.5         -- how close the player must stand to use the target (target mode only)

-- The server re-checks every action at a place (job centre, boss desk, duty point):
-- the player must stand this close (needs OneSync). Set to false only if OneSync is off.
Config.ServerDistanceCheck = true
Config.MaxUseDistance = 4.0         -- metres from the point's coords
Config.CloseDistance = 6.0          -- an open menu closes when the player walks this far from its point

Config.Commands = {
    MyJobs = { 'jobs', 'myjobs' },  -- open "My jobs" (switch active job, duty, quit); first name is the key-mapping command
    BossMenu = 'bossmenu',          -- open the boss menu of your active job (see BossMenu.Anywhere)
    GangMenu = 'gangmenu',          -- open the gang menu (members see their gang, bosses run it)
    Duty = 'duty',                  -- go on / off duty (see Duty.CommandAnywhere)
}
-- Optional key for "My jobs" (players can change it in the game's key settings). '' = no key.
-- Never PageDown (owner rule). Example: 'F6'.
Config.MyJobsKey = ''

---------------------------------
-- multi-job
---------------------------------
Config.MultiJob = {
    -- Most jobs one character may hold. MULTIcore's account limit wins (users.max_jobs,
    -- MULTIConfig.Vorp.MaxJobs, VORP's maxJobsAllowed); this is only used if that can't be read.
    FallbackMaxJobs = 3,
    SwitchCooldownMs = 3000,        -- wait between two job switches (ms)
    OffDutyOnSwitch = true,         -- true = a switched-to job starts off duty (RSG's rsg-multijob does this)
    NotListed = { unemployed = true }, -- jobs never kept in the held-jobs list
    -- Keep RSG's `player_jobs` table in step with the held jobs, so RSG scripts that read or
    -- delete rows there by SQL (e.g. rsg-mdt) agree with MULTIjobs. Changes they make while
    -- the character is offline are taken over at the next login.
    MirrorPlayerJobsTable = true,
}

---------------------------------
-- job centre (employment office)
---------------------------------
-- Jobs anyone may take at a job centre. They start at grade 0. Jobs not listed here
-- (law, medic, judge ...) are only given by their boss or an admin.
-- desc = locale key of the description (locales/*.lua)
Config.PublicJobs = {
    blacksmith   = { desc = 'desc_blacksmith' },
    gunsmith     = { desc = 'desc_gunsmith' },
    butcher      = { desc = 'desc_butcher' },
    generalstore = { desc = 'desc_generalstore' },
    saloon       = { desc = 'desc_saloon' },
    stable       = { desc = 'desc_stable' },
    rancher      = { desc = 'desc_rancher' },
    farmer       = { desc = 'desc_farmer' },
    miner        = { desc = 'desc_miner' },
    lumberjack   = { desc = 'desc_lumberjack' },
    fisherman    = { desc = 'desc_fisherman' },
    hunter       = { desc = 'desc_hunter' },
    herbalist    = { desc = 'desc_herbalist' },
    railroad     = { desc = 'desc_railroad' },
    telegraph    = { desc = 'desc_telegraph' },
    newspaper    = { desc = 'desc_newspaper' },
    undertaker   = { desc = 'desc_undertaker' },
    banker       = { desc = 'desc_banker' },
}
Config.TakeCooldownMs = 10000       -- wait between two job-centre hires for one player (ms)

-- Town halls and government offices. Default spots from an in-game survey of each town
-- hall; check them on your map (stand there and print your coords to adjust).
-- label = locale key of the office name; npc = clerk spot (x, y, z, heading)
Config.JobCentres = {
    { id = 'valentine',  label = 'centre_valentine',  coords = vector3(-170.81, 635.47, 114.09),  npc = vector4(-170.81, 635.47, 114.09, 46.65),  blip = true },
    { id = 'saintdenis', label = 'centre_saintdenis', coords = vector3(2597.44, -1299.02, 52.82), npc = vector4(2597.44, -1299.02, 52.82, 291.30), blip = true },
    { id = 'rhodes',     label = 'centre_rhodes',     coords = vector3(1294.46, -1305.78, 77.04), npc = vector4(1294.46, -1305.78, 77.04, 324.86), blip = true },
    { id = 'blackwater', label = 'centre_blackwater', coords = vector3(-804.08, -1202.60, 44.19), npc = vector4(-804.08, -1202.60, 44.19, 178.48), blip = true },
    { id = 'strawberry', label = 'centre_strawberry', coords = vector3(-1769.61, -379.53, 157.73), npc = vector4(-1769.61, -379.53, 157.73, 185.05), blip = true },
    { id = 'annesburg',  label = 'centre_annesburg',  coords = vector3(2937.23, 1283.60, 44.65),  npc = vector4(2937.23, 1283.60, 44.65, 70.00),   blip = true },
    { id = 'armadillo',  label = 'centre_armadillo',  coords = vector3(-3730.97, -2601.26, -12.94), npc = vector4(-3730.97, -2601.26, -12.94, 177.97), blip = true },
    { id = 'tumbleweed', label = 'centre_tumbleweed', coords = vector3(-5527.21, -2926.81, -1.36), npc = vector4(-5527.21, -2926.81, -1.36, 101.29), blip = true },
    { id = 'vanhorn',    label = 'centre_vanhorn',    coords = vector3(2987.60, 570.85, 44.60),   npc = vector4(2987.60, 570.85, 44.60, 90.00),   blip = true },
}

Config.Npc = {
    Enabled = true,
    Model = 's_m_m_bankclerk_01',   -- checked against the game's ped list
    Scenario = 'WORLD_HUMAN_WRITE_NOTEBOOK', -- what the clerk does (checked against the scenario list); '' = stand still
    SpawnDistance = 25.0,           -- clerk is created when the player is this close, removed beyond it
    ZOffset = -1.0,                 -- added to the clerk z so he stands on the floor
    LoadTimeoutMs = 5000,           -- give up loading the clerk model after this long (ms)
}

Config.Blips = {
    Enabled = true,
    Style = 1664425300,             -- BlipAddForCoords style hash (UNVERIFIED locally: the value RSG v2 scripts use)
    JobCentreSprite = 'blip_ambient_newspaper', -- blip texture name (in femga's blip list)
    Scale = 0.2,
}

---------------------------------
-- boss menu
---------------------------------
Config.BossMenu = {
    -- false = the boss menu opens only at the job's boss desk (Config.BossPoints);
    -- jobs that have no desk listed can always use the command.
    Anywhere = false,
    SameGradeCanManage = false,     -- true = a boss may fire / re-rank staff of the same grade (RSG allows it); false = only lower grades
    HireDistance = 5.0,             -- a new hire must stand this close to the boss (metres)
    HireMakesActive = true,         -- true = the new job becomes the hire's active job (RSG does this)
    -- Pay a boss may set per grade (dollars per paycheck). The boss can't set the pay of
    -- his own grade or above. Per-job limits override the default.
    Pay = {
        Min = 0,
        Max = 0.50,                 -- $0.50 per 10-minute paycheck = $3.00 an hour (1899 wages)
        Jobs = {
            -- vallaw = { Min = 4, Max = 6 },
        },
    },
    MaxMoneyMove = 100000,          -- largest single society deposit / withdrawal (dollars)
}

-- Boss desks (from rsg-bossmenu). job = job name; coords = desk.
Config.BossPoints = {
    { job = 'medic',    coords = vector3(-289.95, 816.24, 119.39) },
    { job = 'vallaw',   coords = vector3(-277.79, 807.43, 119.38) },
    { job = 'rholaw',   coords = vector3(1361.41, -1303.56, 77.77) },
    { job = 'blklaw',   coords = vector3(-762.20, -1266.68, 44.05) },
    { job = 'strlaw',   coords = vector3(-1811.99, -354.03, 164.65) },
    { job = 'stdenlaw', coords = vector3(2508.45, -1308.90, 48.95) },
}

---------------------------------
-- duty
---------------------------------
Config.Duty = {
    CommandAnywhere = true,         -- true = /duty works anywhere; false = only at the job's duty point (jobs without one: anywhere)
    -- No pay for idling (owner's economy rule): a player on duty who does not move for this
    -- many minutes is put off duty. 0 = off.
    AfkMinutes = 15,
    AfkMoveMetres = 2.0,            -- moving less than this counts as standing still
}

-- Duty points (law offices from rsg-lawman, the Valentine doctor from rsg-medic).
Config.DutyPoints = {
    { job = 'vallaw',   coords = vector3(-278.42, 805.29, 119.38) },
    { job = 'rholaw',   coords = vector3(1362.04, -1302.10, 77.77) },
    { job = 'blklaw',   coords = vector3(-761.76, -1268.18, 44.04) },
    { job = 'strlaw',   coords = vector3(-1811.95, -353.94, 164.65) },
    { job = 'stdenlaw', coords = vector3(2507.72, -1301.89, 48.95) },
    { job = 'medic',    coords = vector3(-287.59, 811.28, 118.59) },
}

---------------------------------
-- gangs
---------------------------------
Config.Gang = {
    AccountPrefix = 'gang_',        -- gang money is the MULTIbank account <prefix><gang name>
    RecruitOnlyUnaffiliated = true, -- true = only players in no gang can be recruited
    RecruitDistance = 5.0,          -- a recruit must stand this close to the boss (metres)
    AllowLeave = true,              -- members (not the boss) may leave their gang from "My jobs"
    Anywhere = true,                -- true = /gangmenu works anywhere; false = only at the gang's point below
}

-- Gang hideouts (optional): { gang = 'redwater', coords = vector3(x, y, z) }
Config.GangPoints = {
}

---------------------------------
-- stashes (rsg-bossmenu / rsg-gangmenu style, need an inventory answering as rsg-inventory)
---------------------------------
Config.Stash = {
    Enabled = true,
    MaxWeight = 4000000,            -- grams (RSG default)
    Slots = 50,
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 8,                      -- at most this many actions ...
    WindowMs = 3000,                -- ... in this many milliseconds, per player
}
