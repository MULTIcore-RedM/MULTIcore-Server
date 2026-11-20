fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'MULTIloading'
description 'MULTIcore loading screen: server name, rotating tips, load progress.'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
version '0.1.0'
license 'GPL-3.0'

loadscreen 'html/index.html'
-- MULTIcharacter closes the loading screen once the character select scene is ready
loadscreen_manual_shutdown 'yes'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/config.js',
    'html/custom.css',
    'html/img/*',   -- optional background image (see html/config.js)
    'html/fonts/*', -- optional game fonts (see html/fonts/README.md)
}

dependencies {
    'MULTItarget',   -- MULTIcore's target system (every MULTI script needs it)
}
