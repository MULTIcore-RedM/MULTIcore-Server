fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIwagons'
author 'MULTIcore'
description 'Owned wagons for MULTIcore: dealers, buy / name / sell, take out and put away, storage, damage and repair. Answers as rsg-wagons. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

-- answers to rsg-wagons' name (table rsg_wagons, its events and callbacks).
-- Do not run rsg-wagons on the same server.
provide 'rsg-wagons'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',     -- engine: database, buy / sell / rename, take out / put away, storage, repair, exports
    'server/net.lua',      -- what the game client may ask (distance, rate limit, ownership checked here)
    'server/compat.lua',   -- rsg-wagons events and callbacks
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',     -- dealers, menus, spawning, storage prompt, repair
    'client/compat.lua',   -- rsg-wagons client events
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}
