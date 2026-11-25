fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIrobberies'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore robberies: pick store tills, pick the bank gate, blow the vault with a pipe charge and empty the safes. GPL v3.'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',        -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper
    'client/minigame.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/mg.css',
    'html/mg.js',
    'data/safes.json',
}

dependencies {
    'MULTItarget',
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
    'MULTIdoors',
}
