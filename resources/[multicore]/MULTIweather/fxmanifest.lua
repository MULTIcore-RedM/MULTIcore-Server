fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIweather'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore weather and time: one clock and one sky for every player, weather that changes by itself, admin control.'
version '1.0.0'
license 'GPL-3.0-or-later'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies {
    'MULTIcore',
}
