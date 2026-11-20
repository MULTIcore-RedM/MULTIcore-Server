fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIinventory'
description 'One inventory for RSG and VORP scripts side by side (part of MULTIcore)'
version '0.1.0'
license 'GPL-3.0'

-- answers to both inventory names, so scripts for either framework find it
provide 'rsg-inventory'
provide 'vorp_inventory'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'locales/*.lua',
    'shared/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/*.lua',   -- engine: registry, storage, limits, stashes, drops, usable items
    'server/rsg/*.lua',    -- rsg-inventory face
    'server/vorp/*.lua',   -- vorp_inventory face
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (drops, trade on players)
    'client/core/*.lua',   -- satchel UI, hotbar, weapons on the ped
    'client/rsg/*.lua',    -- rsg-inventory client face
    'client/vorp/*.lua',   -- vorp_inventory client face
}

files {
    'html/**',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'oxmysql',
    'ox_lib',
    'MULTIcore',
}
