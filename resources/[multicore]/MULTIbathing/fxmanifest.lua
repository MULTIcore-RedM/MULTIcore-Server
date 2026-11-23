fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIbathing'
author 'RINGO (RINGOscripting)'
description 'Bath houses for MULTIcore: the game bathing scene, scrubbing, the luxury service and cleanliness. GPL v3.'
version '1.0.0'
license 'GPL-3.0-or-later'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/client.lua',
    'client/structs.js',
}

server_scripts {
    'server/server.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
}
