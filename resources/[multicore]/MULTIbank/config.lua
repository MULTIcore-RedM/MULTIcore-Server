-- ============================================================
-- MULTIbank settings
-- Bank coordinates, clerk spots and door hashes come from the
-- rsg-banking config of the RSG v2 framework (GPL v3, credited in README).
-- ============================================================
Config = {}

Config.Locale = ''                -- language for this script ('de', 'fr' ...); empty = MULTIcore's language (MULTIConfig.Language), else English
Config.Debug = false                -- prints every bank action to the server console
Config.NotifyDuration = 5000        -- how long bank notifications stay on screen (ms)
Config.CheckIntervalMs = 1000       -- how often the client checks clerk distance and walking away from the counter (ms)
Config.QuickAmounts = { 10, 50, 100 } -- quick-fill buttons under the deposit and withdraw boxes (dollars)

---------------------------------
-- how players open the bank
---------------------------------
Config.Interact = 'auto'            -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget, 'prompt' = hold-key prompt at the counter
Config.PromptKey = 'J'              -- key name from MULTIcore's shared/keybinds.lua (prompt mode only)
Config.PromptDistance = 2.0         -- how close the player must stand for the prompt to show (prompt mode only, metres)
Config.TargetIcon = 'fas fa-building-columns' -- MULTItarget icon (target mode only); the label is locale key prompt_open
Config.TargetRadius = 1.2           -- size of the MULTItarget sphere on the counter (target mode only)
Config.TargetDistance = 2.0         -- how close the player must stand to use the target (target mode only)

-- The server re-checks every action: the player must stand this close to the counter
-- (needs OneSync, which MULTIcore servers run). Set to false only if OneSync is off.
Config.ServerDistanceCheck = true
Config.MaxUseDistance = 6.0         -- metres from the bank's counter coords

---------------------------------
-- opening hours (in-game clock)
---------------------------------
-- The game clock lives on the client, so hours are checked when the teller is
-- opened; the server cannot read the game time.
Config.Hours = {
    Enabled = false,                -- false = banks always open
    Open = 9,                       -- opening hour, 24 h clock
    Close = 17,                     -- closing hour, 24 h clock (the bank shuts at Close:00)
}

---------------------------------
-- accounts
---------------------------------
-- false = every bank shares the character's one 'bank' account (VORP style, what most scripts expect).
-- true  = each bank keeps its own account using that bank's `moneytype` (RSG v2 style:
--         valbank, rhobank, blkbank, armbank; Saint Denis uses 'bank'). The money type must
--         exist in MULTIcore's config.lua RSGConfig.Money.MoneyTypes.
Config.SeparateTownAccounts = false

---------------------------------
-- limits and fees (dollars, cents allowed)
---------------------------------
Config.MaxDeposit = 100000          -- largest single deposit
Config.MaxWithdraw = 100000         -- largest single withdrawal
Config.MaxTransfer = 50000          -- largest single transfer
Config.MinAmount = 0.01             -- smallest amount for any action
Config.HardCap = 100000000          -- largest amount any single action or export may move (guards against huge values)
Config.WithdrawFeePercent = 0       -- extra % taken from the account on withdrawal (0 = none)
Config.TransferFeePercent = 0       -- extra % taken from the sender on a transfer (0 = none)

---------------------------------
-- transfers
---------------------------------
Config.Transfer = {
    Enabled = true,
    AllowOffline = true,            -- false = the recipient must be online
}

---------------------------------
-- handing cash to a player close by (rsg-banking's 'give money' event)
---------------------------------
Config.GiveCash = {
    Max = 5000,                     -- most cash handed over at once
    MaxDistance = 5.0,              -- metres between the two players
}

---------------------------------
-- gold exchange
---------------------------------
Config.Gold = {
    Enabled = true,
    BuyPrice = 25.00,               -- dollars the player pays per 1 gold
    SellPrice = 20.00,              -- dollars the player gets per 1 gold
    PayWith = 'cash',               -- 'cash' or 'bank' (the bank's account) pays for / receives the dollars
    MaxPerTrade = 500,              -- most gold bought or sold at once (cents allowed, e.g. 0.5)
}

---------------------------------
-- history (multicore_bank_log)
---------------------------------
Config.History = {
    Rows = 40,                      -- passbook lines shown
    KeepDays = 90,                  -- rows older than this are pruned on resource start (0 = keep forever)
}

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 6,                      -- at most this many bank actions ...
    WindowMs = 3000,                -- ... in this many milliseconds, per player
}

---------------------------------
-- clerk npc
---------------------------------
Config.Npc = {
    Enabled = true,
    Model = 's_m_m_bankclerk_01',   -- checked against the game's ped list
    SpawnDistance = 25.0,           -- clerk is created when the player is this close, removed beyond it
    ZOffset = -1.0,                 -- added to the clerk z so he stands on the floor
    LoadTimeoutMs = 5000,           -- give up loading the clerk model after this long (ms)
}

---------------------------------
-- blips
---------------------------------
Config.Blips = {
    Enabled = true,
    Style = 1664425300,             -- BlipAddForCoords style hash (UNVERIFIED locally: value rsg-banking uses)
    Sprite = 'blip_proc_bank',      -- blip texture name (checked against the game's blip list)
    Scale = 0.2,
}

---------------------------------
-- bank doors (state 0 = unlocked, 1 = locked)
-- Turn off if a door-lock script manages these doors. Skipped by itself while MULTIdoors
-- runs (MULTIdoors locks the bank doors then).
---------------------------------
Config.Doors = {
    Enabled = true,                 -- default true (set the bank door states below)
    DoorScript = 'MULTIdoors',      -- default 'MULTIdoors' (while this resource runs, the bank leaves its doors to it)
    List = {
        -- valentine
        { door = 2642457609, state = 0 }, -- main door
        { door = 3886827663, state = 0 }, -- main door
        { door = 1340831050, state = 1 }, -- barred right
        { door = 2343746133, state = 1 }, -- barred left
        { door = 334467483,  state = 1 }, -- inner door 1
        { door = 3718620420, state = 1 }, -- inner door 2
        { door = 576950805,  state = 1 }, -- vault
        -- rhodes
        { door = 3317756151, state = 0 }, -- main door
        { door = 3088209306, state = 0 }, -- main door
        { door = 2058564250, state = 1 }, -- inner door 1
        { door = 3142122679, state = 1 }, -- inner door 2
        { door = 1634148892, state = 1 }, -- inner door 3
        { door = 3483244267, state = 1 }, -- vault
        -- saint denis
        { door = 2158285782, state = 0 }, -- main door
        { door = 1733501235, state = 0 }, -- main door
        { door = 2089945615, state = 0 }, -- main door
        { door = 2817024187, state = 0 }, -- main door
        { door = 1830999060, state = 1 }, -- inner private door
        { door = 965922748,  state = 1 }, -- manager door
        { door = 1634115439, state = 1 }, -- manager door
        { door = 1751238140, state = 1 }, -- vault
        -- blackwater
        { door = 531022111,  state = 0 }, -- main door
        { door = 2117902999, state = 1 }, -- inner door
        { door = 2817192481, state = 1 }, -- manager door
        { door = 1462330364, state = 1 }, -- vault door
        -- armadillo
        { door = 3101287960, state = 0 }, -- main door
        { door = 3550475905, state = 1 }, -- inner door
        { door = 1329318347, state = 1 }, -- inner door
        { door = 1366165179, state = 1 }, -- back door
    },
}

---------------------------------
-- safe-deposit boxes (a MULTIinventory storage behind the counter)
-- Around 1900 a small box at a town bank rented for a few dollars a year.
---------------------------------
Config.SafeDeposit = {
    Enabled = true,
    PerBank = true,                 -- true = one box per bank; false = one box per character, opened at any bank
    Billing = 'monthly',            -- 'monthly' = pay `fee` every PeriodDays (first period when renting); 'once' = pay `price` once, keep it for good
    PeriodDays = 30,                -- real days one fee covers (monthly billing)
    MaxPrepaid = 3,                 -- most periods that may be paid ahead (monthly billing)
    PayWith = 'bank',               -- 'bank' = the account of the bank you stand at, 'cash' = cash on hand
    -- sizes: slots, weight in grams; price = one-time price (Billing 'once'), fee = each period (Billing 'monthly')
    Tiers = {
        { id = 'small',  label = 'sd_tier_small',  slots = 10, weight = 10000, price = 5.00,  fee = 0.50 },
        { id = 'medium', label = 'sd_tier_medium', slots = 20, weight = 25000, price = 10.00, fee = 1.00 },
        { id = 'large',  label = 'sd_tier_large',  slots = 40, weight = 60000, price = 20.00, fee = 2.00 },
    },
}

---------------------------------
-- money clips (cash folded into an item that can be stored, traded or handed over; use it to get the cash back)
---------------------------------
Config.MoneyClip = {
    Enabled = true,
    Item = 'money_clip',            -- item name (RSG's shared items have it; registered here when missing)
    From = 'cash',                  -- 'cash' = made from cash on hand, 'bank' = from the account of the bank you stand at
    Max = 1000,                     -- most dollars in one clip (cents allowed)
}

---------------------------------
-- banks
---------------------------------
-- id:        short unique name (used in logs; keep it stable)
-- label:     locale key of the name on the blip and the passbook (locales/*.lua)
-- moneytype: account used when Config.SeparateTownAccounts = true
-- coords:    the counter (prompt / target / server distance check)
-- town:      rsg-banking's town name (its safe-deposit event sends it)
-- npc:       clerk position and heading (x, y, z, heading)
Config.Banks = {
    { id = 'valentine',  town = 'Valentine',  label = 'bank_valentine',    moneytype = 'valbank', coords = vector3(-308.4189, 775.8842, 118.7017),  npc = vector4(-308.14, 773.98, 118.7, 4.75),      blip = true },
    { id = 'rhodes',     town = 'Rhodes',     label = 'bank_rhodes',      moneytype = 'rhobank', coords = vector3(1292.307, -1301.539, 77.04012),  npc = vector4(1291.22, -1303.28, 77.04, 316.53),  blip = true },
    { id = 'saintdenis', town = 'SaintDenis', label = 'bank_saintdenis', moneytype = 'bank',    coords = vector3(2644.579, -1292.313, 52.24956),  npc = vector4(2644.75, -1294.15, 52.25, 17.11),   blip = true },
    { id = 'blackwater', town = 'Blackwater', label = 'bank_blackwater',  moneytype = 'blkbank', coords = vector3(-813.1633, -1277.486, 43.63771), npc = vector4(-813.2, -1275.38, 43.64, 173.1),    blip = true },
    { id = 'armadillo',  town = 'Armadillo',  label = 'bank_armadillo',   moneytype = 'armbank', coords = vector3(-3666.25, -2626.57, -13.59),     npc = vector4(-3666.28, -2628.69, -13.59, 359.78), blip = true },
}

