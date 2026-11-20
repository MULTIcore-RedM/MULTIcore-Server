fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIcrafting'
author 'MULTIcore'
description 'MULTIcore basic crafting: campfires, kitchens, workbenches and hand crafting from the satchel. GPL v3.'
version '0.1.0'
license 'GPL-3.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/shared/i18n.lua',
    'config.lua',
    'config/*.lua',
    'locales/*.lua',
}

server_scripts {
    'server/main.lua',      -- stations, recipes, crafting, placed campfires, exports
}

client_scripts {
    '@MULTIcore/lib/interact.lua',  -- MULTItarget / prompt helper (Config.Interact)
    'client/main.lua',      -- prompts / targets, placed campfire props, finding the station nearby
    'client/menu.lua',      -- the crafting screen and the progress bar
}

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'ox_lib',
    'MULTIcore',
    'MULTIinventory',
}
