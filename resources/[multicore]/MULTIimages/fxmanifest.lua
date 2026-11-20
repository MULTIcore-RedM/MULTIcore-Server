fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'MULTIimages'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description 'Item pictures for MULTIinventory and MULTIstores. Put your .png files in images/.'
version '1.0.0'
license 'GPL-3.0-or-later'

-- No scripts: this resource only serves the pictures to the inventory and store pages
-- at nui://MULTIimages/images/<item image>.png
files {
    'images/*.png',
    'images/*.webp',
}
