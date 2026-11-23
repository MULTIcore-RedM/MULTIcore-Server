fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIfarming'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore basic farming: plant seeds, water the crops, harvest them for items the stores buy. GPL v3.'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
    'shared/util.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',        -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Interaction settings)
    'client/main.lua',
    'client/plants.lua',
    'client/use.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/plants.lua',
    'server/admin.lua',
    'server/exports.lua',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
    'oxmysql',
}
