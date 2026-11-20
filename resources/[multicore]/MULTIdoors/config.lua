-- ============================================================
-- MULTIdoors settings
-- Lock rules live in config/locks.lua, town centres in config/towns.lua,
-- every door of the game in data/doors.lua (do not edit that one).
-- ============================================================
Config = Config or {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = server-wide setr multicore_locale, else English
Config.Debug = false                -- prints every lock change, refusal and admin save to the server console
Config.NotifyDuration = 4000        -- how long notifications stay on screen (ms)

---------------------------------
-- doors in the world
---------------------------------
-- Door state written for "locked" (DOOR_SYSTEM_SET_DOOR_STATE). femga natives.json:
-- 0 = unlocked, 1 = locked (unbreakable), 2 = locked (breakable), 3 = held shut (what rsg-doorlock writes).
Config.LockedState = 1
Config.ApplyDistance = 60.0         -- clients set the lock state of managed doors closer than this (metres)
Config.ApplyIntervalMs = 1000       -- how often clients look for managed doors around them (ms)
Config.CloseOnLock = true           -- a door that is locked while standing open swings shut

---------------------------------
-- using a door
---------------------------------
Config.DefaultDistance = 2.0        -- how close a player must stand to a door to lock / unlock it (a rule's `distance` wins)
Config.ServerDistanceCheck = true   -- the server checks the distance too (needs OneSync); false only without OneSync
Config.ServerDistanceSlack = 2.5    -- extra metres the server allows over the rule's distance (movement, lag)
Config.CooldownMs = 1200            -- shortest time between two lock changes by one player (ms)
Config.RequireOnDuty = false        -- true = a job in a rule only counts while the player is on duty
Config.AdminsUseAll = true          -- admins (see Config.Admin) may lock / unlock every managed door
Config.Interact = 'auto'            -- 'auto' = MULTItarget when it runs (else hold-key prompts), 'target' = MULTItarget on the door, 'prompt' = hold-key prompt at the door
Config.PromptKey = 'ENTER'          -- lock / unlock key, name from MULTIcore's shared/keybinds.lua (the key rsg-doorlock uses)
Config.PromptHoldMs = 700           -- how long the key is held (ms)
Config.TargetIcon = 'fas fa-key'    -- MULTItarget icon of "Lock / unlock" (target mode only)
Config.TargetPickIcon = 'fas fa-unlock-keyhole' -- MULTItarget icon of "Pick the lock" (target mode only)
Config.TargetRadius = 0.8           -- size of the MULTItarget sphere on a door (target mode only)

-- Animation while locking / unlocking (dictionary and clip from rsg-doorlock, RSG v2).
Config.Anim = {
    Enabled = true,
    Dict = 'script_common@jail_cell@unlock@key',
    Clip = 'action',
    Flag = 31,                      -- TASK_PLAY_ANIM flags (rsg-doorlock's value)
    DurationMs = 2000,              -- length of the animation (ms)
    ChangeAtMs = 900,               -- the door changes this long after the animation starts (ms)
    Prop = 'p_key02x',              -- key held in the hand ('' = none); redm-info objects.lua
    PropBone = 'SKEL_R_Finger12',   -- bone the key is held by (rsg-doorlock's value)
}

---------------------------------
-- key items
---------------------------------
-- Every item a rule names in `items` is added to the item list at start (MULTIinventory:RegisterItem)
-- when the inventory does not know it yet. Admins give keys with the inventory's own give command.
Config.Keys = {
    Register = true,                -- false = create key items yourself
    Weight = 20,                    -- grams
    Image = 'key.png',              -- image file name in your inventory image folder (missing = plain icon)
}

---------------------------------
-- lockpicking
---------------------------------
Config.Lockpick = {
    Enabled = true,                 -- doors with lockpickable = true may be picked
    Item = 'lockpick',              -- item needed (kept unless it breaks)
    RegisterItem = true,            -- add the item to the item list if the inventory does not know it
    ItemWeight = 50,                -- grams (only when this script adds the item)
    BreakChance = 0.5,              -- chance the lockpick breaks on a failed attempt (0 .. 1)
    Difficulty = { 'easy', 'easy', 'medium' }, -- ox_lib skillCheck rounds
    Inputs = { 'w', 'a', 's', 'd' },-- keys the skill check asks for
    MinMs = 1500,                   -- an attempt faster than this is refused by the server (ms)
    MaxMs = 60000,                  -- an attempt older than this is dropped (ms)
    CooldownSeconds = 8,            -- wait between two attempts by one player
    AnimLoopFlag = 1,               -- TASK_PLAY_ANIM flag while picking (1 = loop)
    Key = 'G',                      -- hold-key for picking (prompt mode), name from MULTIcore's keybinds
}

---------------------------------
-- law alert on lockpicking
---------------------------------
Config.Alert = {
    Enabled = true,                 -- tell the law someone is picking a lock
    Chance = 1.0,                   -- chance an attempt is reported (0 .. 1)
    OnSuccessOnly = false,          -- true = only report a picked lock, false = report every attempt
    JobTypes = { leo = true },      -- job types (MULTIcore shared/jobs.lua `type`) that get the alert
    Jobs = {},                      -- extra job names that get the alert, e.g. { marshal = true }
    OnDutyOnly = true,              -- only players on duty get it
    BlipSeconds = 120,              -- how long the map blip stays
    BlipStyle = 1664425300,         -- BlipAddForCoords style hash (value rsg-medic uses) -- UNVERIFIED (not in femga natives.json)
    BlipSprite = 1109348405,        -- blip sprite hash (value rsg-medic uses) -- UNVERIFIED
    BlipScale = 0.8,                -- blip size
}

---------------------------------
-- admin tool (/doors)
---------------------------------
Config.Admin = {
    Command = 'doors',              -- chat command for the door tool
    Ace = 'multidoors.admin',       -- ACE that opens the tool, e.g.  add_ace group.admin multidoors.admin allow
    RsgPermission = 'admin',        -- RSG permission level that opens it too ('' = ACE only)
    AimDistance = 20.0,             -- how far the aim finder looks (metres)
    AimFallbackRadius = 2.0,        -- when the aim hits no door model, the nearest listed door this close to the hit point
    RayFlags = 17,                  -- shape-test flags: 1 = map, 16 = objects (rsg-doorlock tests doors with 16)
    SelectKey = 'ENTER',            -- picks the aimed door (key name from MULTIcore's keybinds)
    CancelKey = 'BACKSPACE',        -- leaves aim mode
    NearbyRadius = 12.0,            -- "doors near me" list radius (metres)
    MaxListed = 60,                 -- most rows in a list menu
}

---------------------------------
-- rsg-doorlock compatibility
---------------------------------
-- RSG v2 rsg-doorlock's own Config.DoorList (paste it into config/rsg_doorlist.lua) is read too:
-- entry k becomes rule 'rsg_<k>' and answers rsg-doorlock's events by its number.
Config.RsgDoorMatchDistance = 1.0   -- metres between an entry's objCoords and a door in data/doors.lua to count as that door
