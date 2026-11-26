fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'MULTIimages'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'Item pictures for MULTIinventory and MULTIstores. Pictures by Tankie (The Icon Library Project) are included; add your own .png files in images/.'
version '1.1.0'
license 'GPL-3.0-or-later'

-- Serves the pictures to the inventory and store pages at nui://MULTIimages/images/<item image>.png.
-- No scripts of its own. server/standin.lua is run by the stand-ins (vorp_inventory, rsg-inventory,
-- redemrp_inventory, RINGOinventory): each copies these pictures into itself when it starts, so
-- other frameworks' scripts find them at their own paths.

files {
    'images/*.png',
    'images/*.webp',
}
