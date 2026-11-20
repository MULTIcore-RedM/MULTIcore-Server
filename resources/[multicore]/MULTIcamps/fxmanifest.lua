fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIcamps'
author 'MULTIcore'
description 'Basic player camps for MULTIcore: a tent kit pitched in the wild, bedroll, campfire, storage chest, optional hitching post, gang sharing, decay. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

-- No RSG v2 or VORP script calls a camp resource by name, so MULTIcamps answers to no other name.

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',     -- engine: database, place / pack up, storage, sharing, decay, exports
    'server/net.lua',      -- what the game client may ask (distance, rate limit, ownership checked here)
}

client_scripts {
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',     -- placement preview, camp props near the player, camp prompt and menu, sleeping
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}
