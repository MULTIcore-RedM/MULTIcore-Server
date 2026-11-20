-- ============================================================
-- MULTIemotes settings
-- The emote list is in config/emotes.lua, the walk styles in
-- config/walkstyles.lua. Labels are in locales/*.lua
-- ('emote_<id>', 'walk_<id>', 'cat_<category>').
-- ============================================================
Config = {}

Config.Locale = ''                  -- language for this script ('de', 'fr' ...); empty = server-wide setr multicore_locale, else English
Config.Debug = false                -- prints every emote and walk style change to the F8 / server console

---------------------------------
-- opening the menu
---------------------------------
Config.Commands = {
    Menu = 'emotes',                -- chat command that opens the emote menu; '' = none
    Emote = 'e',                    -- /e <name> plays an emote by id or label (/e alone opens the menu); '' = none
    Cancel = 'emotecancel',         -- chat command that stops the current emote; '' = none
    Walk = 'walk',                  -- /walk <style> sets a walk style, /walk reset clears it (/walk alone opens the walk styles); '' = none
    RsgMenu = 'anim',               -- rsg-animations' own command name, kept so players who know it find the menu; '' = none
}
Config.OpenKey = 'F5'               -- default key in the game's key settings for the menu ('' = empty binding, false = none; PageDown is refused)
Config.CancelKey = 'X'              -- key that stops the current emote (name from MULTIcore's shared/keybinds.lua); '' = none
Config.CloseOnPlay = false          -- true = the menu closes when an emote starts

---------------------------------
-- hands up and point keys (client/gestures.lua)
-- Upper body only, so the player can still walk. Not used while typing or in a menu,
-- in an emote, seated or lying, mounted, in a wagon, swimming, cuffed, hogtied or dead.
-- Key = a name from MULTIcore's shared/keybinds.lua ('X', 'B' ...) or a control hash.
---------------------------------
Config.HandsUp = {
    Enabled = true,                 -- false = no hands-up key
    Key = 'X',                      -- default 'X' (while an emote plays, X stops the emote instead)
    Hold = true,                    -- true = hands up while the key is held; false = press to raise, press again to lower
    Holster = true,                 -- put the weapon away first
    -- MULTIlaw looks for this same animation when a lawman searches a player with hands up
    Dict = 'mech_loco_f@generic@reaction@handsup@unarmed@normal',
    Anim = 'loop',
    Flag = 31,                      -- upper body + loop + the player can move
}
Config.Point = {
    Enabled = true,                 -- false = no point key
    Key = 'B',                      -- default 'B'
    Hold = true,                    -- true = point while the key is held; false = press to toggle
    BlockGameKey = true,            -- B is also the game's own satchel key: true keeps the game's satchel shut
    Dict = 'script_common@other@unapproved',
    Anim = 'loop_0',
    Flag = 31,
}

---------------------------------
-- when emotes may be played
---------------------------------
Config.UpperBodyOnMount = true      -- on a horse or in a wagon, game emotes play upper body only; false = not at all
Config.BlockWhenDead = true         -- no emotes while dead or dying
Config.BlockWhenSwimming = true     -- no emotes while swimming
Config.BlockWhenFalling = true      -- no emotes while falling or ragdolled
Config.AnimLoadTries = 20           -- how many times an animation dictionary is asked for before giving up
Config.AnimLoadWaitMs = 100         -- wait between those tries (ms)
Config.AnimBlendIn = 1.0            -- animation blend-in speed (rsg-animations uses 1.0)
Config.AnimBlendOut = 1.0           -- animation blend-out speed (rsg-animations uses 1.0)
Config.PlayingGraceMs = 2000        -- after starting, wait this long before checking whether the emote has ended (ms)
Config.PlayingCheckMs = 500         -- how often a running emote is checked for having ended (ms)
Config.EmoteWatchMs = 15000         -- game emotes end by themselves; the cancel key is watched this long after one starts (ms)

---------------------------------
-- favourites (kept on the player's own PC, client KVP)
---------------------------------
Config.FavouritesKvp = 'multiemotes:favourites' -- KVP key the favourite list is stored under
Config.MaxFavourites = 40           -- most favourites a player can keep

---------------------------------
-- walk styles
---------------------------------
Config.WalkMetadataKey = 'walkstyle' -- player metadata key and state bag name (same as RSG v2 rsg-radialmenu, so both agree)
Config.WalkCooldown = 2             -- seconds between walk style changes (server checked)
Config.WalkSyncMs = 1500            -- how often each client re-applies walk styles to players near it (new peds, respawns)
Config.WalkReapplyDelayMs = 1000    -- wait after spawn / look reload before the own walk style is put back on (ms)

---------------------------------
-- notifications
---------------------------------
Config.NotifyDuration = 4000        -- how long emote notifications stay on screen (ms)
