fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIappearance'
description 'MULTIcore stand-in for rsg-appearance: RSG v2 scripts keep working on the MULTIcore look library'
version '0.1.0'
license 'GPL-3.0-or-later'

-- RSG v2 scripts call exports['rsg-appearance']:X() and fire rsg-appearance:* events;
-- MULTIappearance answers them (do not run rsg-appearance too)
provide 'rsg-appearance'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/data/clothes.lua',     -- every multiplayer piece (index <-> hash)
    '@MULTIcore/data/appearance.lua',  -- palettes (index <-> hash)
    'config.lua',
    'shared/alias.lua',
    'shared/convert.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
}
