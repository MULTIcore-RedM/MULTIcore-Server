-- ============================================================
-- MULTIadmin settings
-- Every option is commented. Permissions are always checked on the
-- server; the menu only shows what the server allows.
-- All text is in locales/<lang>.lua.
-- ============================================================
Config = {}

Config.Locale = ''                -- '' = server-wide `setr multicore_locale xx` (else 'en'); or force one: 'de', 'fr', ...

-- ---------------------------------------------------------------
-- Opening the menu
-- ---------------------------------------------------------------
Config.Command = 'admin'          -- chat command that opens the menu
Config.OpenKey = ''               -- key-settings binding: '' = empty binding, false = none (PageDown is refused)
Config.NoclipCommand = 'adminnoclip'  -- command that toggles noclip without opening the menu
Config.NoclipKey = ''             -- default key for that command ('' = unbound, false = no binding)

-- ---------------------------------------------------------------
-- Permissions
-- "admin" when ANY admin check passes, "mod" when any mod check passes (admins can do all mod things).
--   Levels: RSGCore.Functions.HasPermission(src, level) - rsg-core permission levels (ACE).
--   Ace:    plain IsPlayerAceAllowed(src, name) checks.
-- ---------------------------------------------------------------
Config.Permissions = {
    Admin = { Levels = { 'god', 'admin' }, Ace = { 'multiadmin.admin' } },  -- admin checks
    Mod   = { Levels = { 'mod' },          Ace = { 'multiadmin.mod' } },    -- mod checks
}

-- Level each action needs: 'mod' or 'admin'.
Config.ActionLevel = {
    -- players tab
    ['goto'] = 'mod', bring = 'mod', freeze = 'mod', spectate = 'mod',
    heal = 'mod', revive = 'mod', kill = 'admin',
    kick = 'mod', ban = 'admin', warn = 'mod',
    money = 'admin', job = 'admin', group = 'admin', charmenu = 'admin',
    notify = 'mod',                          -- send a notification to one player or everyone
    -- self tab
    noclip = 'mod', god = 'admin', invisible = 'mod', waypoint = 'mod', coords = 'mod',
    selfheal = 'mod', spawn = 'admin', weather = 'admin', time = 'admin',
    -- server tab
    announce = 'mod', bans = 'admin', unban = 'admin',
}

Config.ProtectHigherRank = true   -- a mod can't kick/ban/kill/freeze/warn/bring/spectate an admin

-- ---------------------------------------------------------------
-- Logging (console always; Discord when the convar holds a webhook)
--   server.cfg:  set multiadmin_webhook "https://discord.com/api/webhooks/..."
-- ---------------------------------------------------------------
Config.WebhookConvar = 'multiadmin_webhook'  -- convar name holding the webhook URL (never put the URL here)
Config.WebhookName = 'MULTIadmin'            -- name Discord posts appear under
Config.WebhookColor = 12073514               -- embed colour (decimal)

-- ---------------------------------------------------------------
-- Notifications (sent through exports.MULTIcore:Notify)
-- ---------------------------------------------------------------
Config.NotifyDuration = 5000          -- ms for normal admin feedback
Config.WarnDuration = 15000           -- ms a warning stays on the warned player's screen
Config.AnnounceDuration = 12000       -- ms an announcement stays on screen
Config.AnnounceStyle = 'banner'       -- MULTIcore notify style for announcements
Config.NotifyTypes = { 'info', 'success', 'warning', 'error' }  -- types the "send notification" form offers
Config.NotifyStyles = { 'toast', 'tip', 'objective', 'banner' } -- styles the "send notification" form offers

-- ---------------------------------------------------------------
-- Player actions
-- ---------------------------------------------------------------
Config.MoneyTypes = { 'cash', 'bank', 'gold', 'rol' }  -- currencies give / take offers (rsg-core money types)
Config.MaxMoneyPerAction = 100000     -- largest amount one give / take may move
Config.Groups = { 'user', 'mod', 'admin', 'superadmin' } -- account groups "set group" may give
Config.GroupsNeedGod = { superadmin = true }             -- groups only the 'god' rsg level may give
Config.WarnKickAt = 0                 -- kick at this many warnings (0 = never)
Config.BanDurations = { 1, 6, 24, 72, 168, 720, 0 }      -- ban length choices in hours (0 = permanent)
Config.BanListLimit = 200             -- most bans the Server tab lists
Config.DateFormat = '%Y-%m-%d %H:%M'   -- how ban dates are shown (Lua os.date format)
Config.BanDbWaitMs = 5000             -- how long a connecting player waits for the ban table at start-up
Config.TextLimits = { Reason = 200, Message = 300, Model = 64 }  -- max characters for reasons, messages, model names
-- Heal / revive go through MULTIcore (Core.Player.Heal / Revive -> its client). true = MULTIadmin also heals / revives the ped itself (only for a core build without those handlers).
Config.LocalHealthFallback = false
Config.HealCoreValue = 100            -- health / stamina core value after a heal (0-100)
Config.ReviveTimeoutMs = 2000         -- fallback revive: wait at most this long for the ped to come back

-- ---------------------------------------------------------------
-- Self tools
-- ---------------------------------------------------------------
Config.Noclip = {
    Speeds = { 1.0, 3.0, 6.0, 12.0, 25.0, 50.0, 100.0 },  -- speed steps in m/s, chosen with the mouse wheel
    StartSpeed = 3,           -- index into Speeds at start
    FastMultiplier = 3.0,     -- while holding Sprint
    SlowMultiplier = 0.25,    -- while holding Duck
    Smoothing = 8.0,          -- how fast speed eases in / out (higher = snappier)
    Controls = {              -- control hashes from the RDR2 control list
        Forward = 0x8FD015D8,   -- INPUT_MOVE_UP_ONLY (W)
        Back = 0xD27782E3,      -- INPUT_MOVE_DOWN_ONLY (S)
        Left = 0x7065027D,      -- INPUT_MOVE_LEFT_ONLY (A)
        Right = 0xB4E465B4,     -- INPUT_MOVE_RIGHT_ONLY (D)
        Up = 0xD9D0E1C0,        -- INPUT_JUMP (Space)
        Down = 0xDE794E3E,      -- INPUT_COVER (Q)
        Fast = 0x8FFC75D6,      -- INPUT_SPRINT (Shift)
        Slow = 0xDB096B85,      -- INPUT_DUCK (Ctrl)
        SpeedUp = 0xCC1075A7,   -- INPUT_PREV_WEAPON (mouse wheel)
        SpeedDown = 0xFD0F0C2C, -- INPUT_NEXT_WEAPON (mouse wheel)
    },
}

Config.Teleport = {
    FadeMs = 250,             -- screen fade out / in
    CollisionTimeoutMs = 3000,-- wait for the world to load at the destination
    ProbeTop = 1000.0,        -- waypoint: start looking for ground this high
    ProbeStep = 50.0,         -- waypoint: step down this much per try
    ProbeWaitMs = 20,         -- waypoint: wait between tries
    FallbackZ = 100.0,        -- waypoint: height used when no ground is found
    Lift = 1.0,               -- metres above the target point
}

Config.Spectate = {
    StopControl = 0x156F7119, -- INPUT_FRONTEND_CANCEL (Backspace / Esc) stops spectating
    Depth = 10.0,             -- the hidden admin ped stays this far below the target
    StreamTimeoutMs = 8000,   -- give up when the target doesn't stream in by then
    FollowFrames = 50,        -- frames between moving the hidden ped under the target
}

Config.Spawn = {
    Distance = 3.0,           -- metres in front of you
    ModelTimeoutMs = 10000,   -- give up loading a model after this
}

Config.StateRecheckMs = 500   -- how often godmode / invisible / freeze are re-applied (survive respawn)
Config.IdleRecheckMs = 1500   -- same loop while nothing is switched on

-- Quick-pick buttons on the Self tab (any valid model name can be typed as well).
Config.SpawnPresets = {
    horses = { 'a_c_horse_arabian_white', 'a_c_horse_tennesseewalker_chestnut', 'a_c_horse_americanstandardbred_black', 'a_c_horse_morgan_bay' },
    wagons = { 'wagon02x', 'wagon05x', 'cart01', 'buggy01', 'coach2', 'chuckwagon000x', 'stagecoach001x' },
}

-- ---------------------------------------------------------------
-- Weather and time (one server-wide state in GlobalState; off if another script owns weather)
-- ---------------------------------------------------------------
Config.WorldSync = true               -- false when weathersync or similar runs
Config.WeatherTransition = 15.0       -- seconds to blend into new weather
Config.TimeTransitionMs = 3000        -- ms to blend to a new time
Config.WorldApplyDelayMs = 2000       -- wait after joining before applying the stored weather / time
Config.WeatherTypes = {               -- weather choices (RDR2 weather type names)
    'sunny', 'clouds', 'overcast', 'overcastdark', 'highpressure', 'misty', 'fog',
    'drizzle', 'shower', 'rain', 'thunder', 'thunderstorm', 'hurricane',
    'hail', 'sleet', 'snowlight', 'snow', 'blizzard', 'groundblizzard', 'whiteout', 'sandstorm',
}

-- ---------------------------------------------------------------
-- Menu page
-- ---------------------------------------------------------------
Config.Ui = {
    ConfirmMs = 3000,         -- how long a "Sure?" button waits for the second click
    RefreshDelayMs = 300,     -- wait before reloading the list after an action
}
