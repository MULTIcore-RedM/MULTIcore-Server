fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIcoroner'
author 'Phil (original phils-coroner); MULTIcore by RINGO (RINGOscripting)'
description 'Coroner inquests for MULTIcore: examine bodies, file reports, carry copies.'
version '1.0.0'
license 'GPL-3.0-or-later'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/coroner.css',
    'html/coroner.js',
    'html/custom.css',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'MULTIcore',
    'MULTItarget',
}
