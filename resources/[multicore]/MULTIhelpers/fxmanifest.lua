fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhelpers'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore stand-ins for the menu, input, progress bar, notification and minigame helper resources scripts depend on (own code, GPL v3).'
version '0.2.0'

-- Scripts that list these as dependencies, or call their exports and events, find this
-- resource instead. Do not also start the real ones (if one starts, MULTIhelpers steps aside for it).
-- VORP
provide 'vorp_menu'
provide 'vorp_inputs'
provide 'vorp_progressbar'
provide 'menuapi'                -- the old VORP menu name
-- RedEM:RP
provide 'redemrp_menu_base'
provide 'redemrp_progressbars'
provide 'redemrp_notification'
-- Gum
provide 'gum_menu'
provide 'gum_notify'
provide 'gum_inputs'
provide 'syn_inputs'
-- TPZ
provide 'tpz_menu_base'
-- RSG v1 / QBR / QB ports
provide 'progressbar'
provide 'rsg-menu'
provide 'qb-menu'
provide 'qbr-menu'
provide 'rsg-input'
provide 'qb-input'
provide 'qbr-input'
provide 'rsg_notify'
-- Feather
provide 'feather-progressbar'
-- others
provide 'syn_minigame'
provide 'fx-minigame'
provide 'fx-input'
provide 'pNotify'
provide 'bln_notify'
-- Feather / BCC
provide 'feather-menu'
provide 'bcc-minigames'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',   -- _L / _LT / _LCode (MULTIcore's shared language helper)
    'config.lua',
    'locales/*.lua',
    'shared/export.lua',            -- registers an export under this name and the stood-in names
}

client_scripts {
    'client/nui.lua',              -- one NUI page, focus shared by every part
    'client/menu.lua',             -- vorp_menu (+ menuapi, gum_menu, tpz_menu_base)
    'client/inputs.lua',           -- vorp_inputs (+ gum_inputs)
    'client/progress.lua',         -- vorp_progressbar
    'client/redem.lua',            -- redemrp_menu_base, redemrp_progressbars
    'client/notify.lua',           -- redemrp_notification, gum_notify, rsg_notify, pNotify, bln_notify
    'client/minigame.lua',         -- syn_minigame, fx-minigame
    'client/qb_input.lua',         -- rsg-input, qb-input, qbr-input, fx-input
    'client/qb_menu.lua',          -- rsg-menu, qb-menu, qbr-menu
    'client/qb_progress.lua',      -- progressbar (QB style)
    'client/feather_progress.lua', -- feather-progressbar
    'client/feather_menu.lua',     -- feather-menu (v1)
    'client/bcc_minigames.lua',    -- bcc-minigames
}

server_scripts {
    'server/notify.lua',           -- bln_notify (server exports)
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/custom.css',       -- owners restyle here (loaded last)
    'html/feather/feather.css',
    'html/feather/feather.js',
    'html/minigames/minigames.css',
    'html/minigames/minigames.js',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'MULTIcore',             -- shared UI theme (html/theme/multi.css), notifications, context menu and input dialog
}
