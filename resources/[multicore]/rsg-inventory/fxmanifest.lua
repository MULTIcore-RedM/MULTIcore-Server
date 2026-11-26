fx_version 'cerulean'
game 'rdr3'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rsg-inventory'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'MULTIcore stand-in: holds the name rsg-inventory for scripts written for RSG-Core (MULTIinventory answers its exports and events) and serves the MULTIimages pictures at nui://rsg-inventory/html/images/'
version '1.0.0'
license 'GPL-3.0-or-later'

-- Holds the name (GetResourceState, dependency, nui://) while MULTIinventory answers every export
-- and event under it. When it starts it copies MULTIimages/images into this folder (the one script
-- below, kept in MULTIimages). Add or change pictures in MULTIimages/images only.
multicore_pictures 'html/images'

server_script '@MULTIimages/server/standin.lua'

files {
    'html/images/*.png',
    'html/images/*.webp',
}

dependencies {
    'MULTIimages',      -- the pictures
    'MULTIinventory',   -- the inventory scripts reach under this name
}
