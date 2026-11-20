fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIserver'
author 'MULTIcore'
description 'MULTIcore basic server tools: Discord logs (answers rsg-log), whitelist, connect queue, player list, server info. GPL v3.'
version '0.1.0'

-- answers rsg-log:server:CreateLog (see README); do not also run a script that answers it (rsg-essentials' logs.lua)
provide 'rsg-log'

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
    'server/logs.lua',
    'server/whitelist.lua',
    'server/queue.lua',
    'server/players.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
}
