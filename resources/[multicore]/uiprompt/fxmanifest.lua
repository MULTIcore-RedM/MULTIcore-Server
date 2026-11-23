fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

name 'uiprompt'
author 'RINGO (RINGOscripting)'    -- founder of MULTIcore
description "MULTIcore's stand-in for the uiprompt library: scripts include @uiprompt/uiprompt.lua for the Uiprompt, UipromptGroup and UipromptManager classes (own code, GPL v3)."
version '1.0.0'

-- Nothing runs in this resource itself. Scripts load the file into their own resource with
--   client_scripts { '@uiprompt/uiprompt.lua', ... }
-- so it only has to be listed here and the resource started before them.
files {
    'uiprompt.lua',
}
