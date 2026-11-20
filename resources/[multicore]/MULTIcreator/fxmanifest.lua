fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIcreator'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore character creator and barber'
version '0.1.0'
license 'GPL-3.0-or-later'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',   -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    '@MULTIcore/lib/interact.lua',    -- MULTItarget / prompt helper (Config.Barber.interact)
    '@MULTIcore/data/appearance.lua', -- overlays, palettes, face sliders (game data)
    '@MULTIcore/data/clothes.lua',    -- every mp piece (game data)
    'client/data.lua',
    'client/main.lua',
    'client/barber.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/custom.css',
    'html/app.js',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
}
