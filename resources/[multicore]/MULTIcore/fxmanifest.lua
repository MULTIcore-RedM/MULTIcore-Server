fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIcore'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'One core for RSG, VORP and RedEM:RP scripts side by side. Built on rsg-core 2.4.1 (see CREDITS.md).'
version '0.1.0'

-- MULTIcore answers to every framework name, so scripts that depend on any of them find it
provide 'rsg-core'
provide 'vorp_core'
provide 'redem_roleplay'

ui_page 'html/notify/index.html'

shared_scripts {
    'shared/alias.lua',          -- must be first: every export is also registered under rsg-core
    '@ox_lib/init.lua',
    'config.lua',
    'config_multi.lua',
    'shared/i18n.lua',         -- MULTI language helper (_L / _LT / _LCode)
    'config_notify.lua',
    'locales/*.lua',           -- MULTI words (notify_*.lua); RSG's stay in locale/
    'shared/locale.lua',
    'locale/en.lua',
    'locale/*.lua',
    'shared/main.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/vehicles.lua',
    'shared/gangs.lua',
    'shared/weapons.lua',
    'shared/locations.lua',
    'shared/keybinds.lua',
    'data/appearance.lua',     -- face sliders, overlays, palettes (game data)
    'data/clothes.lua',        -- every multiplayer clothing and body piece (game data)
}

client_scripts {
    'lib/ui.lua',               -- ox_lib menus and dialogs in the MULTI look (client/multi/ui.lua)
    'client/main.lua',
    'client/functions.lua',
    'client/loops.lua',
    'client/events.lua',
    'client/drawtext.lua',
    'client/prompts.lua',
    'client/pvp.lua',
    'client/multi/*.lua',      -- look apply library, login events
    'client/vorp/*.lua',       -- VORP client face
    'client/redem/*.lua',      -- RedEM:RP client face
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/multi/schema.lua',
    'server/functions.lua',
    'server/moneyitems.lua',
    'server/player.lua',
    'server/events.lua',
    'server/commands.lua',
    'server/exports.lua',
    'server/debug.lua',
    'server/multi/accounts.lua',
    'server/multi/jobs.lua',
    'server/multi/appearance.lua',
    'server/multi/login.lua',
    'server/vorp/callbacks.lua',
    'server/vorp/notify.lua',
    'server/multi/notify.lua',  -- after functions.lua and the VORP notify, before vorp/core.lua
    'server/vorp/character.lua',
    'server/vorp/core.lua',
    'server/vorp/events.lua',
    'server/redem/player.lua',             -- RedEM:RP face: the player object
    'server/redem/core.lua',               -- RedEM:RP face: RedEM object, callbacks, events
    'server/multi/compat_characters.lua',  -- VORP characters table + RSG playerskins kept in step
    'server/multi/compat_vorp.lua',        -- getUserByCharId export, vorp:setjob
    'server/multi/api.lua',        -- MULTIcore's own API (docs/API.md)
    'server/multi/interact.lua',   -- /mcinteract: one line per MULTI script in the server console
    'server/multi/testhooks.lua',  -- inert unless the test convar is set
}

files {
    'shared/i18n.lua',         -- language helper every MULTI script includes (@MULTIcore/shared/i18n.lua)
    'lib/api.lua',             -- MC.* shortcut for MULTIcore's own API (@MULTIcore/lib/api.lua)
    'lib/ui.lua',              -- ox_lib menus in the MULTI look every MULTI script with menus includes (@MULTIcore/lib/ui.lua)
    'lib/interact.lua',        -- MULTItarget / prompt helper every MULTI script with world points includes (@MULTIcore/lib/interact.lua)
    'sql/*.sql',
    'html/theme/*',
    'html/theme/fonts/*',      -- game fonts when present (see html/theme/fonts/README.md)
    'html/theme/img/*',        -- MULTIcore brand mark and logo
    'html/notify/*',
    'html/ui/*',               -- menus and dialogs (client/multi/ui.lua)
}

dependencies {
    'oxmysql',
    'ox_lib',
}
