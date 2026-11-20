fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIbank'
author 'MULTIcore'
description 'MULTIcore banks: deposit, withdraw, transfer, gold exchange, passbook history. GPL v3.'
version '0.1.0'

-- MULTIbank stands in for rsg-banking (see README "rsg-banking compatibility").
-- Do not run rsg-banking on the same server.
provide 'rsg-banking'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/safedeposit.lua', -- safe-deposit boxes and money clips (uses MULTIinventory)
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
