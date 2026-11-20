fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIstores'
author 'MULTIcore'
description 'Stores for MULTIcore: general stores, gunsmiths, butchers, trappers, doctors, saloons. Answers as rsg-shops. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

-- answers to rsg-shops' name, so RSG scripts that open rsg-shops stores find it.
-- Do not run rsg-shops on the same server.
provide 'rsg-shops'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',     -- store engine, exports, buy / sell
    'server/compat.lua',   -- rsg-inventory shop exports, rsg-shops event
}

client_scripts {
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',     -- prompts / targets, blips, clerks, store screen
}

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
    'MULTIinventory',
}
