-- ============================================================
-- MULTItelegram settings
-- Post office places are in config/offices.lua (taken from the
-- rsg-telegram config of the RSG v2 framework, GPL v3, see CREDITS.md).
-- ============================================================
Config = {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = server-wide setr multicore_locale, else English
Config.Debug = false                -- prints every telegram action to the server console
Config.NotifyDuration = 6000        -- how long telegram notifications stay on screen (ms)
Config.CheckIntervalMs = 1000       -- how often the client checks clerk distance and walking away from the counter (ms)

---------------------------------
-- price (1899: a telegram cost a few cents; RDR2 shows no price for one)
---------------------------------
Config.Price = 0.10                 -- cash taken for every telegram sent (dollars, cents allowed, 0 = free)

---------------------------------
-- where things may be done
---------------------------------
Config.ReadAnywhere = false         -- true = the inbox opens anywhere (/telegram); false = only at a post office
Config.ContactsAnywhere = true      -- true = the address book can be edited anywhere (/addressbook); sending always needs an office
Config.AllowSendToSelf = false      -- true = a character may send a telegram to itself (testing)
Config.MaxUseDistance = 6.0         -- metres from an office counter for sending, collecting parcels and reading (server checked, needs OneSync)

---------------------------------
-- how players open the post office
---------------------------------
Config.Interact = 'auto'            -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget on the counter and clerk, 'prompt' = hold-key prompt
Config.PromptKey = 'J'              -- key name from MULTIcore's shared/keybinds.lua (prompt mode only)
Config.PromptDistance = 2.0         -- how close the player must stand for the prompt to show (prompt mode only, metres)
Config.TargetIcon = 'fas fa-envelope' -- MULTItarget icon (target mode only); the label is locale key prompt_open
Config.TargetRadius = 1.2           -- size of the MULTItarget sphere on the counter (target mode only)
Config.TargetDistance = 2.0         -- how close the player must stand to use the target (target mode only)
Config.Commands = {
    Inbox = 'telegram',             -- chat command that opens the inbox (same name as rsg-telegram's); '' = none
    Contacts = 'addressbook',       -- chat command that opens the address book (same name as rsg-telegram's); '' = none
}

---------------------------------
-- limits
---------------------------------
Config.MaxSubject = 60              -- longest subject line (characters)
Config.MaxMessage = 1000            -- longest message (characters)
Config.MaxRecipient = 60            -- longest recipient entry (name, id or citizen id)
Config.MaxContactName = 40          -- longest name in the address book
Config.MaxContacts = 50             -- most address book entries per character
Config.InboxRows = 60               -- newest telegrams shown in the inbox
Config.DateFormat = '%x'            -- os.date format of the sent date (rsg-telegram uses '%x')

---------------------------------
-- arrival notices
---------------------------------
Config.LoginNoticeDelayMs = 8000    -- after a character loads, wait this long, then tell them how many telegrams wait
Config.PollSeconds = 30             -- how often new rows written straight into the telegrams table by other scripts are announced (0 = never)

---------------------------------
-- spam guard
---------------------------------
Config.RateLimit = {
    Calls = 8,                      -- at most this many telegram actions ...
    WindowMs = 4000,                -- ... in this many milliseconds, per player
}
Config.SendCooldownMs = 5000        -- smallest gap between two telegrams sent by one player (ms)

---------------------------------
-- parcels (an item sent with a telegram, held by the post office until collected)
---------------------------------
Config.Parcel = {
    Enabled = false,                -- off by default; true = a satchel item can be sent with a telegram
    Price = 0.25,                   -- extra cash for a parcel (dollars)
    MaxAmount = 10,                 -- most of one item in a parcel
    AllowWeapons = false,           -- true = weapons may be posted too
    Blacklist = {                   -- item names that can never be posted
        -- money_clip = true,
    },
}

---------------------------------
-- clerk npc (only at offices whose `npc` is set in config/offices.lua)
---------------------------------
Config.Npc = {
    Enabled = true,
    Model = 's_m_m_trainstationworker_01', -- checked against the game's ped list
    SpawnDistance = 25.0,           -- clerk is created when the player is this close, removed beyond it
    ZOffset = -1.0,                 -- added to the clerk z so he stands on the floor
    LoadTimeoutMs = 5000,           -- give up loading the clerk model after this long (ms)
}

---------------------------------
-- blips
---------------------------------
Config.Blips = {
    Enabled = true,
    Style = 1664425300,             -- BlipAddForCoords style hash (the value RSG v2 scripts use)
    Sprite = 'blip_post_office',    -- blip texture name (the one rsg-telegram uses)
    Scale = 0.2,
}
