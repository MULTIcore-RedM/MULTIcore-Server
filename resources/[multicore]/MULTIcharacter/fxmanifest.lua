fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIcharacter'
description 'MULTIcore character select: up to 5 characters, delete, spawn picker, first-spawn flow.'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
version '0.1.0'
license 'GPL-3.0'

-- RSG v2 scripts that depend on these start, and their client events are handled here
provide 'rsg-multicharacter'
provide 'rsg-spawn'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
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
    'html/style.css',
    'html/app.js',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'oxmysql',
    'MULTIcore',
}
