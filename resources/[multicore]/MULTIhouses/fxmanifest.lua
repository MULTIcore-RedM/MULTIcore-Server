fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhouses'
author 'RINGO (RINGOscripting)'
description 'Houses for MULTIcore: buy a house with a deposit, pay off the balance, land tax credit, guest keys, a house stash, outfits, door locks and break-ins. GPL v3.'
version '1.0.0'
license 'GPL-3.0-or-later'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',        -- ox_lib dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',          -- multi_houses, multi_housekeys, multi_housedoors: made and filled on start
    'server/server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/houses.css',
    'html/custom.css',
    'html/script.js',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'oxmysql',
    'MULTIcore',
    'MULTIinventory',
}
