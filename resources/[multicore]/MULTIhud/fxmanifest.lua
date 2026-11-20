fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIhud'
author 'MULTIcore'
description 'MULTIcore HUD and needs: health, stamina, hunger, thirst, stress, cleanliness, temperature, horse, money, voice. Stands in for vorp_metabolism and answers the rsg-hud events.'
version '0.1.0'
license 'GPL-3.0-or-later'

-- VORP food and drink scripts talk to vorp_metabolism; this resource answers in its place.
-- Do not run vorp_metabolism or rsg-hud on the same server.
provide 'vorp_metabolism'
provide 'rsg-hud'

shared_scripts {
    '@MULTIcore/shared/i18n.lua',  -- _L / _LT / _LCode
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',     -- HUD: reads the game, sends to the NUI page
    'client/needs.lua',    -- activity / shooting reports, starving effects
    'client/compat.lua',   -- vorp_metabolism events, rsg-hud events
}

server_scripts {
    'server/needs.lua',    -- decay loop, writes through the RSGCore player metadata
    'server/compat.lua',   -- rsg-hud server events, exports
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/hud.css',
    'html/hud.js',
    'html/custom.css',
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
    'MULTIcore',
}
