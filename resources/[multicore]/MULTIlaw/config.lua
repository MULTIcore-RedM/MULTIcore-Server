-- ============================================================
-- MULTIlaw :: settings
-- Every option has a one-line comment and its default. Places (offices,
-- cells, Sisika, bounty boards) are in config/places.lua.
-- ============================================================
Config = {}

Config.Locale = nil                 -- nil = server-wide `setr multicore_locale`, or a code such as 'de'
Config.Debug = false                -- true = print what the server decides (refusals, compat calls)
Config.NotifyDuration = 5000        -- how long MULTIlaw's notifications stay (ms)

---------------------------------
-- who counts as the law
---------------------------------
Config.LawTypes = { leo = true, doj = true } -- MULTIcore job types that are law ('leo' = town law and marshals, 'doj' = the court)
Config.RequireOnDuty = true         -- true = law tools only work while on duty (MULTIjobs duty points / /duty)
Config.AdminPermission = 'admin'    -- RSGCore permission that may uncuff / release anyone (also from the admin menu)
-- Which job types may do what. Remove a type to take the tool away from it.
Config.Permissions = {
    cuff       = { leo = true },             -- put on / take off handcuffs
    escort     = { leo = true },             -- lead a cuffed or downed player
    vehicle    = { leo = true },             -- put into / take out of a wagon or horse
    search     = { leo = true },             -- open a cuffed / hands-up / downed player's satchel
    confiscate = { leo = true },             -- take an item into the evidence locker
    jail       = { leo = true, doj = true }, -- send to a cell or Sisika
    release    = { leo = true, doj = true }, -- let a prisoner go early
    fine       = { leo = true, doj = true }, -- write a fine
    bounty     = { leo = true, doj = true }, -- post or take down a bounty
    records    = { leo = true, doj = true }, -- read criminal records at an office
    evidence   = { leo = true, doj = true }, -- open the evidence locker at an office
    alerts     = { leo = true },             -- receive law alerts (map blips)
}

---------------------------------
-- server checks
---------------------------------
Config.ServerDistanceCheck = true   -- true = the server checks distances with OneSync (leave on)
Config.RateLimit = { WindowMs = 3000, Calls = 10 } -- most law actions one player may send per window

---------------------------------
-- world interaction
---------------------------------
Config.Interact = 'auto'            -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget spheres, 'prompt' = hold-key prompt at offices and boards
Config.PromptKey = 'G'              -- key name from MULTIcore's shared/keybinds.lua (J is MULTIjobs' duty prompt)
Config.PromptDistance = 2.0         -- how close the player must stand for an office / board prompt to show (prompt mode, metres)
Config.TargetIcons = {              -- MULTItarget icons (Font Awesome)
    office = 'fas fa-star',         -- law office
    board = 'fas fa-scroll',        -- bounty board
    player = 'fas fa-star',         -- law actions on a player
}
Config.TargetRadius = 1.2           -- MULTItarget sphere size at a place (metres)
Config.TargetDistance = 2.0         -- MULTItarget reach at a place (metres)
Config.CloseDistance = 4.0          -- a board or records page closes when you walk this far away (metres)
Config.PlayerTarget = true          -- add the law actions to every player through MULTItarget (if it runs)
Config.PlayerTargetDistance = 2.0   -- MULTItarget reach on players (metres)

---------------------------------
-- handcuffs, escort, wagons, search
---------------------------------
Config.Cuff = {
    Item = 'handcuffs',             -- item the lawman must carry ('' = none needed)
    RequireItem = true,             -- true = no cuffs without the item
    UseItem = true,                 -- true = using the item cuffs / uncuffs the nearest player
    Distance = 2.0,                 -- how close the lawman must stand (metres)
    Hard = false,                   -- true = cuffed players can't walk (frozen), false = they can walk with cuffed hands
    KeepOnRelog = true,             -- true = a player who logs out in cuffs is still cuffed on the next login
}
Config.Escort = {
    Distance = 2.5,                 -- how close the lawman must stand to start leading (metres)
    Bone = 11816,                   -- lawman bone the prisoner is held at (rsg-lawman's)
    Offset = vector3(0.45, 0.45, 0.0), -- where beside the lawman the prisoner walks
}
Config.Vehicle = {
    Distance = 6.0,                 -- wagon / horse must be this close to the lawman (metres)
    TargetDistance = 4.0,           -- prisoner must be this close to the lawman (metres)
    MountSeat = 0,                  -- horse seat for the prisoner (0 = behind the rider)  -- UNVERIFIED seat index
}
Config.Search = {
    Distance = 2.5,                 -- how close the lawman must stand (metres)
    AllowCuffed = true,             -- search a cuffed player
    AllowHandsUp = true,            -- search a player with hands up (the game's hands-up loop)
    AllowRestrained = true,         -- search a hogtied or lassoed player
    AllowDead = true,               -- search a downed player
    HandsUpDict = 'script_proc@robberies@homestead@lonnies_shack@deception', -- hands-up animation (rsg-essentials)
    HandsUpAnim = 'hands_up_loop',
    StateCheckMs = 500,             -- how often a player's own client reports hands up / hogtied
}
Config.Evidence = {
    Slots = 60,                     -- evidence locker slots per office
    MaxWeight = 400000,             -- evidence locker weight (grams)
    ConfiscateMax = 1000,           -- most of one item taken in one go
    Prefix = 'multilaw_evidence_',  -- stash name prefix (+ office id)
}

---------------------------------
-- jail and Sisika
---------------------------------
Config.Jail = {
    Distance = 5.0,                 -- lawman must stand this close to the prisoner (metres); export / MDT jails skip it
    RequireCuffed = false,          -- true = only cuffed players can be jailed
    CellMaxMinutes = 30,            -- longest stay in a town cell
    PrisonMaxMinutes = 240,         -- longest stay at Sisika
    CellSearchRadius = 400.0,       -- a town cell must be this close to the lawman, else he must pick Sisika (metres)
    TickSeconds = 15,               -- how often the server checks release times
    AllowEscape = false,            -- false = a prisoner who leaves the cell / prison grounds is put back
    EscapeCheckMs = 2000,           -- how often the prisoner's position is checked
    RemoveJob = false,              -- true = going to Sisika costs the player his job (rsg-prison did this)
    TakeItems = { cell = false, prison = true }, -- satchel taken on arrival, given back on release
    ItemStashPrefix = 'multilaw_jailitems_', -- where taken items wait (+ citizenid)
    PrisonOutfit = true,            -- true = Sisika uniform (rsg-prison's pieces), look restored on release
    FadeMs = 800,                   -- screen fade when moved in / out
}

---------------------------------
-- fines (money goes to a MULTIbank account)
---------------------------------
Config.Fines = {
    Min = 0.25,                     -- smallest fine ($)
    Max = 50.00,                    -- biggest fine ($); 1899 town fines were a few dollars
    Account = 'job',                -- 'job' = the officer's job account (e.g. 'vallaw'), or any fixed name such as 'county'
    PayFrom = { 'cash', 'bank' },   -- money tried in this order when paying
    Distance = 5.0,                 -- officer must stand this close to write a fine (metres)
    MaxUnpaid = 20,                 -- most unpaid fines one character may have
    ReasonLength = 80,              -- longest reason text
}

---------------------------------
-- wanted posters and bounties
---------------------------------
Config.Bounty = {
    Min = 1.00,                     -- smallest reward ($)
    Max = 250.00,                   -- biggest reward ($)
    ExpireHours = 72,               -- a poster comes down after this many real hours
    Account = 'job',                -- reward paid from: 'job' = the posting officer's job account, or a fixed name
    PerTarget = 3,                  -- most open posters on one person
    ReasonLength = 120,             -- longest reason text
    PayTo = 'cash',                 -- the jailing lawman gets the reward as 'cash' or 'bank'
    ClaimOwn = true,                -- true = the officer who posted a bounty may also claim it
    PostAnywhere = false,           -- false = posters are put up at a law office only
}

---------------------------------
-- records
---------------------------------
Config.Records = {
    Anywhere = false,               -- false = records open at a law office only
    MaxEntries = 100,               -- newest entries shown per person
    SearchLimit = 40,               -- most people listed per search
}

---------------------------------
-- law alerts
---------------------------------
Config.Alerts = {
    BlipSeconds = 60,               -- how long an alert blip stays
    RemoveWithin = 5.0,             -- blip goes once the lawman reaches it (metres)
    GPS = true,                     -- route to the newest alert
    Cooldown = 20000,               -- one player may send an alert this often (ms)
    MaxCoordsOffset = 150.0,        -- a client-sent alert position must be this close to the sender (metres)
    TextLength = 120,               -- longest alert text
    Style = 'BLIP_STYLE_CREATOR_DEFAULT', -- rsg-lawman's blip
    RingStyle = 'BLIP_STYLE_COP_PERSISTENT',
    Sprite = 'blip_ambient_law',
    RingSprite = 'blip_overlay_ring',
    Modifier = 'BLIP_MODIFIER_AREA_PULSE',
    Scale = 0.8,
    RingScale = 2.0,
}

---------------------------------
-- badge (rsg-lawman's /lawbadge: the star on the coat)
---------------------------------
Config.Badge = {
    Enabled = true,                 -- false = no /lawbadge
    Male = 0xDB4C451D,              -- shop item for men (rsg-lawman)
    Female = 0x0929677D,            -- shop item for women (rsg-lawman)
}

---------------------------------
-- map blips
---------------------------------
Config.Blips = {
    Offices = true,                 -- blip on each law office
    OfficeSprite = 'blip_ambient_sheriff',
    Prison = true,                  -- blip on Sisika
    PrisonSprite = 'blip_mp_roles_bounty_hunter_lock',
    Boards = false,                 -- blip on each bounty board
    BoardSprite = 'blip_proc_bounty_poster', -- bounty poster blip (name from rsg-adminmenu's blip list)
    Style = 1664425300,             -- blip style used by rsg-lawman / MULTIjobs
    Scale = 0.2,
}

---------------------------------
-- commands ('' = off)
---------------------------------
Config.Commands = {
    Cuff = 'cuff',                  -- cuff / uncuff the nearest player
    Escort = 'escort',              -- lead / let go of the nearest cuffed player
    PutIn = 'putin',                -- put the nearest cuffed player into the nearest wagon or onto a horse
    TakeOut = 'takeout',            -- take the nearest prisoner out of a wagon or off a horse
    Search = 'searchplayer',        -- search the nearest player
    Confiscate = 'confiscate',      -- take an item from the nearest searched player into evidence
    Jail = 'jail',                  -- /jail [id] [minutes]  (no id = nearest player, asks the rest)
    Unjail = 'unjail',              -- /unjail id
    Fine = 'fine',                  -- write a fine for the nearest player
    MyFines = 'fines',              -- list and pay your own fines
    Badge = 'lawbadge',             -- put the badge on / off
    LawMenu = 'lawmenu',            -- the law actions menu (on the nearest player)
}

---------------------------------
-- RSG compatibility (rsg-lawman, rsg-prison)
---------------------------------
Config.Compat = {
    TrustAdminCuff = true,          -- rsg-adminmenu's cuff event is honoured when it names an admin as the cuffer
    AllowOutlawReset = true,        -- 'rsg-prison:server:resetoutlawstatus' (rsg-medic) sets the sender's outlawstatus to 0
    MaxOutlawStep = 100,            -- biggest single 'updateoutlawstatus' change a client may send
    MetaJailPlace = 'prison',       -- where a jail set by another script (metadata injail, rsg-mdt) is served: 'prison' or 'cell'
    StoragePrefix = 'lawstorage',   -- rsg-lawman's law storage stash name (+ job name)
    StorageSlots = 50,              -- rsg-lawman's storage slots
    StorageMaxWeight = 4000000,     -- rsg-lawman's storage weight (grams)
}
