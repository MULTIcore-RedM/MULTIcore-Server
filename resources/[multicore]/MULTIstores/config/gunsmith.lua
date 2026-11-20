-- ============================================================
-- MULTIstores :: gunsmith stock
-- A gunsmith sells every weapon in MULTIinventory's weapon data
-- (exports.MULTIinventory:GetWeaponData()), every ammo box / bundle, a round
-- item for any ammo type that has no box, and the extra items below.
-- Prices are 1899-level (owner decision, 2026-11-18): RDR2's own story-mode gunsmith
-- prices where they are known (Cattleman $50, Schofield $84, Springfield $120, Carcano $190 ...),
-- otherwise close to them or to historical 1899 catalogue prices. The old economy SPEC
-- is no longer the price source. A weapon not named in Weapons gets its group's price;
-- `false` keeps it out of the store.
-- Weapons bought here are made through MULTIinventory, so each gets its own serial.
-- ============================================================

Config.Gunsmith = {
    WeaponStock = 3,                -- default 3 (stock of each weapon; nil = never runs out)
    AmmoStock = 40,                 -- default 40 (stock of each ammo box / bundle)
    ThrownStock = 20,               -- default 20 (stock of each thrown weapon: knives, tomahawks, dynamite ...)

    -- price by weapon group, used when a weapon is not in Weapons below
    GroupPrices = {
        revolver = 65, pistol = 150, repeater = 120, rifle = 150, sniper = 190, varmint = 72,
        shotgun = 120, bow = 30, melee = 5, thrown = 2, lasso = 2, held = 7, fishing = 2.50,
    },

    Weapons = {
        -- revolvers (RDR2: Cattleman $50, Double-Action $65, Schofield $84)
        weapon_revolver_cattleman            = 50.00,
        weapon_revolver_cattleman_mexican    = 60.00,
        weapon_revolver_doubleaction         = 65.00,
        weapon_revolver_doubleaction_gambler = 90.00,
        weapon_revolver_schofield            = 84.00,
        weapon_revolver_navy                 = 110.00,
        weapon_revolver_navy_crossover       = 130.00,
        weapon_revolver_lemat                = 150.00,
        -- pistols (RDR2: Volcanic $150, Semi-Automatic $210, Mauser $250)
        weapon_pistol_volcanic               = 150.00,
        weapon_pistol_semiauto               = 210.00,
        weapon_pistol_mauser                 = 250.00,
        weapon_pistol_m1899                  = 275.00,
        -- lever repeaters (RDR2: Carbine $90, Lancaster $135, Litchfield $145)
        weapon_repeater_carbine              = 90.00,
        weapon_repeater_winchester           = 135.00,
        weapon_repeater_henry                = 145.00,
        weapon_repeater_evans                = 160.00,
        -- rifles (RDR2: Varmint $72, Springfield $120, Bolt-Action $180)
        weapon_rifle_varmint                 = 72.00,
        weapon_rifle_springfield             = 120.00,
        weapon_rifle_boltaction              = 180.00,
        weapon_rifle_elephant                = 350.00,
        -- long-range rifles (RDR2: Rolling Block $187, Carcano $190)
        weapon_sniperrifle_rollingblock      = 187.00,
        weapon_sniperrifle_carcano           = 190.00,
        weapon_sniperrifle_rollingblock_exotic = 250.00,
        -- shotguns (RDR2: Sawed-Off $85, Double-Barreled $95, Pump-Action $148, Repeating $185, Semi-Auto $225)
        weapon_shotgun_sawedoff              = 85.00,
        weapon_shotgun_doublebarrel          = 95.00,
        weapon_shotgun_pump                  = 148.00,
        weapon_shotgun_repeating             = 185.00,
        weapon_shotgun_doublebarrel_exotic   = 140.00,
        weapon_shotgun_semiauto              = 225.00,
        -- bows (1899: a hunting bow $3-10; set near RDR2's level)
        weapon_bow                           = 30.00,
        weapon_bow_improved                  = 60.00,
        -- knives and blades (RDR2 fence: hatchet $4.25, cleaver $8, machete $10; 1899 hunting knife $1-3)
        weapon_melee_knife                   = 2.50,
        weapon_melee_knife_rustic            = 3.00,
        weapon_melee_knife_trader            = 4.00,
        weapon_melee_knife_jawbone           = 6.00,
        weapon_melee_knife_horror            = 6.00,
        weapon_melee_machete                 = 10.00,
        weapon_melee_machete_horror          = 12.00,
        weapon_melee_machete_collector       = 15.00,
        weapon_melee_hatchet                 = 4.25,
        weapon_melee_hatchet_hunter          = 5.00,
        weapon_melee_hatchet_double_bit      = 6.00,
        weapon_melee_cleaver                 = 8.00,
        weapon_melee_torch                   = 0.25,
        -- thrown, priced per piece (RDR2 fence: dynamite $1, fire bottle $0.75, throwing knife $2.50, tomahawk $4)
        weapon_thrown_throwing_knives        = 2.50,
        weapon_thrown_tomahawk               = 4.00,
        weapon_thrown_tomahawk_ancient       = 10.00,
        weapon_thrown_dynamite               = 1.00,
        weapon_thrown_molotov                = 0.75,
        weapon_thrown_poisonbottle           = 1.00,
        weapon_thrown_bolas                  = 3.00,
        weapon_thrown_bolas_hawkmoth         = 5.00,
        weapon_thrown_bolas_intertwined      = 5.00,
        weapon_thrown_bolas_ironspiked       = 6.00,
        -- tools (1899: rope $2, barn lantern $1.50, field glasses $5-15, pocket camera $5, fishing rod $2.50)
        weapon_lasso                         = 2.00,
        weapon_lasso_reinforced              = 6.00,
        weapon_melee_lantern                 = 1.50,
        weapon_melee_davy_lantern            = 2.50,
        weapon_melee_lantern_halloween       = 3.00,
        weapon_kit_binoculars                = 7.00,
        weapon_kit_binoculars_improved       = 12.00,
        weapon_kit_camera                    = 5.00,
        weapon_kit_camera_advanced           = 15.00,
        weapon_kit_metal_detector            = 40.00,
        weapon_fishingrod                    = 2.50,
    },

    -- ammo boxes and bundles (1899: a box of 50 revolver cartridges about $1; rifle and
    -- shotgun shells a little more; special ammo 1.5-4x the normal box). Any box
    -- MULTIinventory knows that is missing here is not sold.
    Ammo = {
        ammo_box_revolver                    = 1.00,
        ammo_box_revolver_express            = 1.50,
        ammo_box_revolver_velocity           = 1.50,
        ammo_box_revolver_splitpoint         = 2.00,
        ammo_box_revolver_explosive          = 3.00,
        ammo_box_pistol                      = 1.00,
        ammo_box_pistol_express              = 1.50,
        ammo_box_pistol_velocity             = 1.50,
        ammo_box_pistol_splitpoint           = 2.00,
        ammo_box_pistol_explosive            = 3.00,
        ammo_box_repeater                    = 1.25,
        ammo_box_repeater_express            = 1.75,
        ammo_box_repeater_velocity           = 1.75,
        ammo_box_repeater_splitpoint         = 2.25,
        ammo_box_repeater_explosive          = 3.50,
        ammo_box_rifle                       = 1.50,
        ammo_box_rifle_express               = 2.00,
        ammo_box_rifle_velocity              = 2.00,
        ammo_box_rifle_splitpoint            = 2.50,
        ammo_box_rifle_explosive             = 4.00,
        ammo_box_rifle_elephant              = 3.00,
        ammo_box_varmint                     = 0.75,
        ammo_box_varmint_tranquilizer        = 1.50,
        ammo_box_shotgun                     = 1.25,
        ammo_box_shotgun_slug                = 2.00,
        ammo_box_shotgun_buckshot_incendiary = 3.00,
        ammo_box_shotgun_slug_explosive      = 3.50,
        ammo_arrow                           = 1.00,
        ammo_arrow_small                     = 1.00,
        ammo_arrow_fire                      = 1.50,
        ammo_arrow_poison                    = 1.50,
        ammo_arrow_dynamite                  = 2.50,
    },
    -- price of one round for ammo types that have no box (e.g. special throwing knives)
    RoundPrices = {
        ammo_throwing_knives_drain           = 3.00,
        ammo_throwing_knives_poison          = 3.00,
    },

    -- other items a gunsmith sells (cleaning / repair kit; 1899: gun oil and rod about 75c)
    Extra = {
        { name = 'weapon_repair_kit', price = 0.75, amount = 15, category = 'tools' },
        { name = 'handcuffs',         price = 2.50, amount = 10, category = 'tools' },      -- 1899: a pair of handcuffs $2-3
        { name = 'resource_lead_bar', price = 0.15, amount = 50, category = 'materials' },  -- for casting bullets (crafting)
        { name = 'gunpowder',         price = 0.25, amount = 50, category = 'materials' },  -- 1899: a pound of black powder 25c
    },
}
