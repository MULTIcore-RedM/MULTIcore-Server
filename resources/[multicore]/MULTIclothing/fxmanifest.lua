fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIclothing'
description 'MULTIcore clothing stores, wardrobes, saved outfits and quick clothing toggles'
version '0.1.0'
license 'GPL-3.0-or-later'

-- RSG v2 scripts call exports['rsg-wardrobe']:X(); MULTIclothing answers them (do not run rsg-wardrobe too)
provide 'rsg-wardrobe'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua', -- _L / _LT / _LCode (must come before config.lua)
    'config.lua',
    'locales/*.lua',
    'shared/alias.lua',
}

client_scripts {
    '@MULTIcore/lib/ui.lua',   -- ox_lib menus and dialogs in the MULTI look
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',
    'client/store.lua',
    'client/outfits.lua',
    'client/toggles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@MULTIcore/data/clothes.lua',     -- piece counts, to check what the client sends
    '@MULTIcore/data/appearance.lua',  -- palette count, same reason
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
    'oxmysql',
    'ox_lib',
    'MULTIcore',
}
