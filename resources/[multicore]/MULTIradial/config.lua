-- ============================================================
-- MULTIradial :: config
-- The quick menu: MC crest in the middle, buttons on both sides, Cancel / Back below.
-- Every button text is a locale key (locales/*.lua), icons are Font Awesome names (fontawesome.com).
-- ============================================================

Config = {}

Config.Locale = nil                 -- language ('en', 'de' ...); nil = MULTIcore's language (MULTIConfig.Language), else 'en'

Config.Keybind = 'F6'               -- key that opens the menu (name from MULTIcore shared/keybinds.lua)
Config.HoldToOpen = false           -- false = tap to open, click a button (or Cancel / Esc) to close
                                    -- true  = hold the key, let go to close
Config.Command = 'radial'           -- chat command that opens it too ('' = none)
Config.Scale = 1.0                  -- size of the whole menu (1 = normal)
Config.PerPage = 8                  -- most buttons on one page (4 each side); more go under "More"

-- ---------------------------------------------------------------
-- Buttons
--   label  = locale key        icon = Font Awesome name
--   one of:
--     items   = { ... }                      a sub menu
--     command = 'emotes'                      runs a chat command (as if the player typed /emotes)
--     event   = 'name', server = true|false   fires a client (or server) event
--     clothing = 'hat'                        takes that piece off / puts it back on
--                                             (rsg-wardrobe names: hat, masks, coats, vest, glove, ...)
--     dress = true / undress = true           puts everything back on / takes everything off
--   job = { 'medic', ... }                    only shown to these jobs (optional)
-- Buttons for a script that is not running are left out by themselves (resource = 'MULTIhorses').
-- ---------------------------------------------------------------
Config.Menu = {
    { label = 'm_clothing', icon = 'shirt', resource = 'MULTItailor', items = {
        { label = 'c_hat',       icon = 'hat-cowboy',    clothing = 'hat' },
        { label = 'c_mask',      icon = 'mask',          clothing = 'masks' },
        { label = 'c_neckwear',  icon = 'user-tie',      clothing = 'neckwear' },
        { label = 'c_eyewear',   icon = 'glasses',       clothing = 'eyewear' },
        { label = 'c_coat',      icon = 'vest-patches',  clothing = 'coats' },
        { label = 'c_vest',      icon = 'vest',          clothing = 'vest' },
        { label = 'c_gloves',    icon = 'mitten',        clothing = 'glove' },
        { label = 'c_gunbelt',   icon = 'gun',           clothing = 'gunbelts' },
        { label = 'c_shirt',     icon = 'shirt',         clothing = 'shirt' },
        { label = 'c_pants',     icon = 'socks',         clothing = 'pants' },
        { label = 'c_boots',     icon = 'shoe-prints',   clothing = 'boots' },
        { label = 'c_satchel',   icon = 'bag-shopping',  clothing = 'satchels' },
        { label = 'c_dress',     icon = 'person',        dress = true },
        { label = 'c_undress',   icon = 'person-walking', undress = true },
    } },
    { label = 'm_emotes',   icon = 'face-smile',     resource = 'MULTIemotes', command = 'emotes' },
    { label = 'm_walk',     icon = 'person-walking', resource = 'MULTIemotes', command = 'walk' },
    { label = 'm_satchel',  icon = 'briefcase',      resource = 'MULTIinventory', command = 'inventory' },
    { label = 'm_horse',    icon = 'horse',          items = {
        { label = 'h_find',  icon = 'magnifying-glass-location', resource = 'MULTIhorses', command = 'findhorse' },
        { label = 'h_flee',  icon = 'horse-head',     resource = 'MULTIhorses', command = 'fleehorse' },
        { label = 'h_wagon', icon = 'truck-pickup',   resource = 'MULTIwagons', command = 'wagon' },
    } },
    { label = 'm_telegram', icon = 'envelope',       resource = 'MULTItelegram', command = 'telegram' },
    { label = 'm_crafting', icon = 'screwdriver-wrench', resource = 'MULTIcrafting', command = 'craft' },
    { label = 'm_settings', icon = 'gear',           items = {
        { label = 's_hud',       icon = 'eye',            resource = 'MULTIhud', command = 'hud' },
        { label = 's_hudedit',   icon = 'up-down-left-right', resource = 'MULTIhud', command = 'hudedit' },
        { label = 's_hudreset',  icon = 'rotate-left',    resource = 'MULTIhud', command = 'hudreset' },
        { label = 's_voice',     icon = 'microphone',     resource = 'MULTIvoice', command = 'voice' },
        { label = 's_emotestop', icon = 'hand',           resource = 'MULTIemotes', command = 'emotecancel' },
    } },
}
