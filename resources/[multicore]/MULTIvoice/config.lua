-- ============================================================
-- MULTIvoice :: config
-- Proximity voice on the server's own voice chat. Every option has a one-line comment.
-- server.cfg needs (they are in server.cfg.example):
--     setr voice_use3dAudio true
--     setr voice_useSendingRangeOnly true
-- Talking itself uses the game's push-to-talk key (N by default, set in the game's own settings).
-- ============================================================

Config = {}

-- Config.Locale = 'en'           -- language for this script only (else MULTIcore's language (MULTIConfig.Language), else English)

-- Voice ranges, cycled with Config.CycleKey or /voice. 'label' is a locale key (shown on the HUD).
Config.Ranges = {
    { label = 'range_whisper', distance = 2.0 },
    { label = 'range_normal',  distance = 6.0 },
    { label = 'range_shout',   distance = 15.0 },
}
Config.DefaultRange = 2           -- which range a player starts in (2 = normal)

Config.CycleKey = 'GRAVE'         -- ` (the key left of 1): next voice range. A key name for the game's key settings (players can change it
                                  -- there), or a control hash from MULTIcore shared/keybinds.lua; false = command only
Config.Command = 'voice'          -- /voice cycles the range too; /voice 1, 2 or 3 picks one ('' = no command)
Config.Notify = true              -- show the new range in a notification when it changes
Config.UpdateMs = 250             -- how often the list of players in range is rebuilt (ms)

-- Radio and call channels: only used when another script puts a player on a radio or a call
-- (telegraph lines, lawman radios ...). Calls are always open; the radio is push-to-talk.
Config.Radio = {
    Enabled = true,               -- false = radio calls from other scripts are ignored
    Key = 0x430593AA,             -- [ : hold to talk on the radio
    Volume = 0.6,                 -- 0.0 - 1.0, how loud radio voices are
}
Config.Call = {
    Enabled = true,               -- false = call channels from other scripts are ignored
    Volume = 0.6,                 -- 0.0 - 1.0, how loud a call is
}
