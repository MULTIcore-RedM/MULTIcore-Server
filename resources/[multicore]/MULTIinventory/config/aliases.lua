-- ============================================================
-- MULTIinventory :: other names for the same item, weapon or ammo type
-- Scripts from other developers spell names their own way. MULTIinventory turns those names
-- into the item, weapon or ammo type this server has, so giving, taking, counting and using
-- them all land on the one thing. Most spellings are caught on their own:
--   - any capitalisation               AMMO_BOX_REVOLVER      -> ammo_box_revolver
--   - _ - . and spaces ignored         ammo-box-revolver      -> ammo_box_revolver
--   - the rules in Config.AliasRules   ammo_revolver_normal   -> ammo_revolver
--                                      ammo_box_rifle_highvelocity -> ammo_box_rifle_velocity
-- Only names that are not an item themselves are changed. Add your own below when a script
-- uses a name none of these catch (left = the script's name, right = your item).
-- With Config.Debug = true the server console shows every name it turned into another.
-- ============================================================

-- item name a script uses = item name on this server
Config.ItemAliases = {
    -- ['revolver_ammo'] = 'ammo_box_revolver',
    -- ['bandage_roll']  = 'bandage',
    ammo_varmint           = 'ammo_22',
    ammo_varmint_tranq     = 'ammo_22_tranquilizer',
    ammo_box_22            = 'ammo_box_varmint',
    ammo_box_22_tranquilizer = 'ammo_box_varmint_tranquilizer',
    ammo_arrow_normal      = 'ammo_arrow',
    ammo_arrow_smallgame   = 'ammo_arrow_small',
    ammo_arrow_small_game  = 'ammo_arrow_small',
}

-- weapon name a script uses = the game's weapon name
Config.WeaponAliases = {
    -- ['WEAPON_MY_CUSTOM_REVOLVER'] = 'WEAPON_REVOLVER_CATTLEMAN',
}

-- ammo type a script uses = the game's ammo type (AMMO_X_NORMAL -> AMMO_X and VARMINT -> 22 are automatic)
Config.AmmoAliases = {
    -- ['AMMO_REVOLVER_REGULAR'] = 'AMMO_REVOLVER',
}

-- Spelling rules tried on an unknown item name (Lua patterns on the lower-case name; each rule
-- alone and every pair of rules). The first result that is an item wins.
Config.AliasRules = {
    { '_normal$', '' },                    -- ammo_revolver_normal -> ammo_revolver
    { 'normal$', '' },
    { 'varmint', '22' },                   -- ammo_varmint -> ammo_22
    { '_22', '_varmint' },                 -- ammo_box_22 -> ammo_box_varmint
    { '_tranq$', '_tranquilizer' },
    { 'highvelocity', 'velocity' },        -- ammo_box_rifle_highvelocity -> ammo_box_rifle_velocity
    { 'high_velocity', 'velocity' },
    { '_velocity$', '_high_velocity' },    -- ammo_rifle_velocity -> ammo_rifle_high_velocity
    { 'splitpoint', 'split_point' },
    { 'split_point', 'splitpoint' },
    { '_explosive$', '_express_explosive' },
    { '_express_explosive$', '_explosive' },
    { 'smallgame', 'small' },
    { 'small_game', 'small' },
}
