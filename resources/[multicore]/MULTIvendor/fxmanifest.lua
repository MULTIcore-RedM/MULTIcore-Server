fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MULTIvendor'
author 'Mack; MULTIcore by RINGO (RINGOscripting)'
license 'GPL-3.0-or-later'
description 'Sell goods to vendor NPCs from your satchel'
version '1.0.0'

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'locales/de.lua',
    'locales/es.lua',
    'locales/fr.lua',
    'locales/it.lua',
    'locales/nl.lua',
    'locales/pl.lua',
    'locales/pt-br.lua',
    'locales/ru.lua',
    'locales/tr.lua',
    'locales/locales.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    'server/server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/custom.css',
    'html/script.js',
}

dependencies {
    'MULTIcore',
    'MULTIinventory',
}
