-- ============================================================
-- MULTIserver settings
-- Basic server tools: Discord logs (answers rsg-log), whitelist,
-- connect queue, player list and server info.
-- Webhook URLs NEVER go in this file. Put them in server.cfg as
-- plain server-side convars (set, not setr), see README.
-- ============================================================
Config = {}

Config.Locale = ''                      -- language for this script ('de', 'fr' ...); empty = MULTIcore's language (MULTIConfig.Language), else English
Config.Debug = false                    -- prints extra lines (queue moves, whitelist checks) to the server console
Config.NotifyDuration = 5000            -- how long command answers stay on screen (ms)

---------------------------------
-- who counts as staff (player list extra columns, whitelist commands)
---------------------------------
Config.AdminAce = { 'multiserver.admin', 'multiadmin.admin', 'multiadmin.mod' }  -- any of these ACE names = staff
Config.AdminLevels = { 'god', 'admin', 'mod' }  -- rsg-core permission levels that count as staff

---------------------------------
-- Discord logs (answers TriggerEvent('rsg-log:server:CreateLog', name, title, color, message, tagEveryone))
--   server.cfg:  set multiserver_webhook "https://discord.com/api/webhooks/..."            (default for every log)
--                set multiserver_webhook_playermoney "https://discord.com/api/webhooks/..." (one log name)
---------------------------------
Config.Logs = {
    Enabled = true,                     -- false = MULTIserver ignores every log call
    ConvarPrefix = 'multiserver_webhook', -- convar names: <prefix> (default) and <prefix>_<logname> (override)
    UseDefault = true,                  -- true = names without their own webhook go to the default webhook
    Ignore = {},                        -- log names never sent anywhere, e.g. { 'playerinventory' }
    ConsoleFallback = true,             -- print a log to the server console when no webhook is set for it
    ConsoleAlways = false,              -- also print every log to the console when it does go to Discord
    BotName = 'MULTIserver',            -- name the Discord posts appear under
    AvatarConvar = 'multiserver_webhook_avatar', -- optional convar with an image URL for the poster's avatar (empty = Discord default)
    AllowTagEveryone = true,            -- false = never ping @everyone, even when a script asks for it
    MaxMessageLength = 3900,            -- longer messages are cut (Discord allows 4096 in an embed description)
    MaxTitleLength = 240,               -- longer titles are cut (Discord allows 256)
    -- sending queue
    SendGapMs = 600,                    -- wait between two posts (Discord allows about 5 posts per 2 seconds per webhook)
    MaxQueue = 500,                     -- most logs waiting; beyond this the oldest is dropped (console warning)
    MaxRetries = 5,                     -- tries per log when Discord says "too many requests" (429) or is down (5xx)
    RetryFallbackMs = 2000,             -- wait after a 429 when Discord gives no retry time (ms)
    ErrorRetryMs = 5000,                -- wait before retrying after a 5xx or no answer (ms)
    -- logs sent by game clients (RSG's admin menu and medic send theirs from the client)
    Client = {
        Enabled = true,                 -- false = only logs from server scripts are taken
        Names = { death = true, adminmenu = true }, -- log names a client may send; anything else from a client is refused
        PerMinute = 6,                  -- most logs one player may send per minute
        MaxLength = 500,                -- client messages are cut to this length
    },
    -- colour names scripts use (decimal colour codes). Numbers and '#rrggbb' work too.
    Colors = {
        default = 14423100, blue = 255, red = 16711680, green = 65280, white = 16777215,
        black = 0, orange = 16744192, yellow = 16776960, pink = 16761035, lightgreen = 65309,
    },
    -- MULTI events MULTIserver logs itself (only events that the MULTI scripts really fire)
    Events = {
        CharacterCreated = 'character', -- MULTIcore:characterSelected (new character) -> this log name; false = off
        Jailed = 'law',                 -- MULTIlaw:server:jailed -> this log name; false = off
        Released = 'law',               -- MULTIlaw:server:released -> this log name; false = off
    },
}

---------------------------------
-- whitelist (off by default)
---------------------------------
Config.Whitelist = {
    Enabled = false,                    -- true = only identifiers in the multiserver_whitelist table may join
    Identifiers = { 'license', 'license2', 'steam', 'discord' }, -- identifier kinds that may be listed and are checked on join
    BypassAce = 'multiserver.whitelist.bypass', -- ACE that lets a player in without a row (e.g. give it to group.admin)
    CommandAce = 'multiserver.whitelist', -- ACE for the commands below (staff from Config.AdminAce may use them too)
    AddCommand = 'wladd',               -- /wladd <server id | license:... | steam:... | discord:...> [note]
    RemoveCommand = 'wlremove',         -- /wlremove <server id | identifier>
    CheckCommand = 'wlcheck',           -- /wlcheck <server id | identifier>
    DbWaitMs = 10000,                   -- how long a joining player waits for the database after a restart (ms)
    MaxNoteLength = 120,                -- longest note stored with a row
}

---------------------------------
-- connect queue (off by default)
---------------------------------
Config.Queue = {
    Enabled = false,                    -- true = players wait in a queue when the server is full
    MaxPlayers = 0,                     -- slots; 0 = sv_maxclients
    PriorityAce = 'multiserver.priority', -- ACE prefix: multiserver.priority.1 .. .MaxPriority (higher number goes first)
    MaxPriority = 5,                    -- highest priority level checked
    GraceMinutes = 5,                   -- a player who dropped within this many minutes rejoins ahead of everyone
    GracePriority = 100,                -- priority given to a rejoining player inside the grace time
    UpdateMs = 2000,                    -- how often the queue moves and the waiting card is refreshed (ms)
    JoinTimeoutSec = 120,               -- a let-in player who has not arrived after this many seconds frees the slot again
    Card = false,                       -- true = waiting screen as an adaptive card, false = plain text
}

---------------------------------
-- player list (scoreboard)
---------------------------------
Config.PlayerList = {
    Enabled = true,                     -- false = no player list
    Command = 'players',                -- chat command that opens / closes the list
    Key = '',                           -- default key in the game's key settings ('' = unbound; PageDown is never bound)
    ShowCharacterName = true,           -- false = players do not see character names (staff still do)
    ShowJob = true,                     -- false = no job column for players (staff still see it)
    ShowPing = true,                    -- false = no ping column
    CooldownMs = 1000,                  -- shortest time between two list requests from one player (ms)
}

---------------------------------
-- server info (/info)
---------------------------------
Config.Info = {
    Enabled = true,                     -- false = no info panel
    Command = 'info',                   -- chat command that opens the panel
    Key = '',                           -- default key in the game's key settings ('' = unbound)
    ServerName = '',                    -- name shown at the top; '' = the server's sv_hostname
    Description = '',                   -- a few lines about the server; '' = the text from locales ('info_default_desc')
    Rules = '',                         -- link to your rules (shown with a copy button); '' = hidden
    Discord = '',                       -- Discord invite link (shown with a copy button); '' = hidden
    Website = '',                       -- website link; '' = hidden
    ShowPlayerCount = true,             -- show "players online / slots"
}
