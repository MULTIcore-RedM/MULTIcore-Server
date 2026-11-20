fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIconsumables'
author 'MULTIcore'
description 'MULTIcore food, drink, tobacco and medicine: usable items with animations, a drunk system and addictions. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

server_scripts {
    'server/00_state.lua',
    'server/10_drunk.lua',
    'server/20_addiction.lua',
    'server/30_use.lua',
    'server/40_main.lua',
}

client_scripts {
    'client/use.lua',
    'client/effects.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
    'MULTIhud',
}
