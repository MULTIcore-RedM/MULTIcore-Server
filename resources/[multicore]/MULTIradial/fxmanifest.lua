fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIradial'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore quick menu (F6): clothing, emotes, walk styles, satchel, horse and wagon, telegram, crafting, HUD settings. Stands in for rsg-radialmenu.'
version '0.1.0'
license 'GPL-3.0-or-later'

-- RSG scripts add their own buttons through exports['rsg-radialmenu']:AddOption(...); MULTIradial answers.
-- Do not run rsg-radialmenu on the same server.
provide 'rsg-radialmenu'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/radial.css',
    'html/radial.js',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'MULTIcore',
}
