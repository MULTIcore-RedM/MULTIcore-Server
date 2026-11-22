Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

-- Active locale. Available: de, en, es, fr, it, nl, pl, pt-br, ru, tr
Config.Locale = 'en'

-- Keybind that opens the vendor menu when standing at a prompt
Config.Keybind = 'J'

-- Distance (meters) before spawning/despawning the vendor ped
Config.DistanceSpawn = 20.0

-- How far (meters) from the vendor or its prompt spot a sale is accepted (checked on the server)
Config.SellDistance = 10.0

-- Smooth fade in/out when spawning/despawning the ped
Config.FadeIn = true

-- ============================================================================
-- DEFAULT NPC PED (override per-vendor with ped = { model, scenario })
-- ============================================================================
Config.DefaultPed = {
    model = 'U_M_M_ValGunSmith_01',
    scenario = 'WORLD_HUMAN_LEAN_BACK_WALL',
}

-- ============================================================================
-- DEFAULT BLIP SETTINGS
-- ============================================================================
Config.Blip = {
    enabled = true,
    sprite = 819673798,
    scale = 0.2,
}

-- ============================================================================
-- NOTIFICATION SETTINGS (MULTIcore notifications; look and placement are set in MULTIcore)
-- ============================================================================
Config.Notification = {
    DefaultDuration = 4000,
}

-- ============================================================================
-- SELL MENU SETTINGS (NUI)
-- ============================================================================
Config.SellMenu = {
    -- Currency symbol used when formatting prices
    Currency = '$',

    -- Quick sell amounts offered when an item has more than this many units.
    -- Only amounts smaller than the player's stock are shown.
    QuickSellAmounts = { 1, 5, 10, 25, 50 },

    -- Optional category map used for the UI filter tabs, e.g.
    --   Categories = { ['corn'] = 'Farming', ['goldwatch'] = 'Jewelry' }
    -- Items not listed here appear under the "All" tab. Leave empty to
    -- disable the category tabs entirely.
    Categories = {},

    -- Show the "Sell Everything" option in the sell menu
    ShowSellEverything = true,
}

-- ============================================================================
-- VENDORS
-- Each vendor buys exactly the items in its ItemPrices table.
--   name        = display name used for prompts, blips and menu title
--   coords      = where the vendor ped spawns
--   heading     = ped heading
--   promptCoords = where the player stands to open the menu
--   blipName    = blip label
--   ped         = optional per-vendor override of Config.DefaultPed
--   ItemPrices  = itemName -> price in $ per unit
-- ============================================================================
Config.Vendors = {
    -------------------------------------------------
    -- 1) Produce Buyer
    -------------------------------------------------
    {
        name     = 'Produce Buyer',
        coords       = vector3(-281.31, 654.52, 113.56),
        heading      = 131.26,
        promptCoords = vector3(-282.89, 653.02, 113.56), -- Move in front of counter
        blipName = 'Produce Buyer',
        -- ped = { model = 'OVERRIDE', scenario = 'OVERRIDE' },
        ItemPrices = {
            ["corn"]        = 2,
            ["wheat"]       = 2,
            ["sugar"]       = 2,
            ["tobacco"]     = 4,
            ["indtobacco"]  = 4,
            ["carrot"]      = 2,
            ["tomato"]      = 2,
            ["broccoli"]    = 2,
            ["potato"]      = 2,
            ["cotton"]      = 2,
            ["banana"]      = 5,
            ["coconut"]     = 5,
            ["mango"]       = 5,
            ["melon"]       = 5,
            ["kiwi"]        = 5,
            ["pineapple"]   = 5,
            ["orange"]      = 5,
            ["lemon"]       = 5,
            ["hay"]         = 1,
            ["egg"]         = 0.01,   -- the general store sells eggs for $0.03: more here would be a money loop
            ["haybale"]     = 10,
            ["crayfish"]    = 2,
            ["bluecrab"]    = 3,
            ["carrotbox"]   = 50,
            ["cornsack"]    = 50,
            ["wheatsack"]   = 50,
            ["sugarsack"]   = 60,
            ["applesbox"]   = 60,
            ["tomatobox"]   = 50,
            ["broccolibox"] = 50,
            ["potatobox"]   = 50,
        },
    },
    -------------------------------------------------
    -- 2) Herb Buyer
    -------------------------------------------------
    {
        name     = 'Herb Buyer',
        coords       = vector3(-279.29, 652.10, 113.56),
        heading      = 119.73,
        promptCoords = vector3(-281.20, 650.49, 113.56), -- Move in front of counter
        blipName = 'Herb Buyer',
        ItemPrices = {
            ["provision_wldflwr_agarita"]           = 1.5,
            ["consumable_herb_alaskan_ginseng"]     = 1.5,
            ["consumable_herb_american_ginseng"]     = 1.5,
            ["consumable_herb_bay_bolete"]           = 1.5,
            ["provision_wldflwr_bitterweed"]         = 1.5,
            ["provision_wldflwr_blood_flower"]       = 1.5,
            ["provision_wldflwr_cardinal_flower"]    = 1.5,
            ["consumable_herb_chanterelles"]         = 1.5,
            ["provision_wldflwr_chocolate_daisy"]    = 1.5,
            ["provision_wldflwr_creek_plum"]         = 1.5,
            ["consumable_herb_creeping_thyme"]       = 1.5,
            ["consumable_herb_english_mace"]         = 1.5,
            ["consumable_herb_evergreen_huckleberry"]= 1.5,
            ["consumable_herb_golden_currant"]       = 1.5,
            ["consumable_herb_hummingbird_sage"]     = 1.5,
            ["consumable_herb_indian_tobacco"]       = 1.5,
            ["consumable_herb_milkweed"]             = 1.5,
            ["consumable_herb_oleander_sage"]        = 1.5,
            ["consumable_herb_vanilla_flower"]       = 1.5,
            ["consumable_herb_red_sage"]             = 1.5,
            ["provision_wldflwr_texas_blue_bonnet"]  = 1.5,
            ["consumable_herb_violet_snowdrop"]      = 1.5,
            ["provision_wldflwr_wild_rhubarb"]       = 1.5,
            ["consumable_herb_wintergreen_berry"]    = 1.5,
            ["provision_wldflwr_wisteria"]           = 1.5,
            ["consumable_herb_yarrow"]               = 1.5,
            ["consumable_herb_harrietum"]            = 1.5,
            ["consumable_herb_black_berry"]          = 1.5,
            ["consumable_herb_red_raspberry"]        = 1.5,
            ["consumable_herb_desert_sage"]          = 1.5,
            ["consumable_herb_burdock_root"]         = 1.5,
            ["consumable_herb_wild_mint"]            = 1.5,
            ["consumable_herb_parasol_mushroom"]     = 1.5,
            ["consumable_herb_rams_head"]            = 1.5,
            ["consumable_herb_wild_feverfew"]        = 1.5,
            ["consumable_herb_prairie_poppy"]        = 1.5,
            ["consumable_herb_wild_carrots"]         = 1.5,
            ["consumable_herb_black_currant"]        = 1.5,
            ["consumable_herb_oregano"]              = 1.5,
            ["consumable_herb_common_bulrush"]       = 1.5,
            ["provision_ro_flower_acunas_star"]      = 1.5,
            ["provision_ro_flower_cigar"]            = 1.5,
            ["provision_ro_flower_clamshell"]        = 1.5,
            ["provision_ro_flower_dragons"]          = 1.5,
            ["provision_ro_flower_ghost"]            = 1.5,
            ["provision_ro_flower_lady_of_night"]    = 1.5,
            ["provision_ro_flower_lady_slipper"]     = 1.5,
            ["provision_ro_flower_moccasin"]         = 1.5,
            ["provision_ro_flower_night_scented"]    = 1.5,
            ["provision_ro_flower_queens"]           = 1.5,
            ["provision_ro_flower_rat_tail"]         = 1.5,
            ["provision_ro_flower_sparrows"]         = 1.5,
            ["provision_ro_flower_spider"]           = 1.5,
            ["consumable_herb_saltbush"]             = 1.5,
            ["herbs"]                                = 1.5,
        },
    },
    -------------------------------------------------
    -- 3) Jewelry Buyer
    -------------------------------------------------
    {
        name     = 'Jewelry Buyer',
        coords       = vector3(2658.97, -1290.33, 51.49),
        heading      = 15.20,
        promptCoords = vector3(2657.27, -1289.51, 51.48), -- Move in front of counter
        blipName = 'Jewelry Buyer',
        ItemPrices = {
            ["pocket_watch"]                           =  135,
            ["pocket_watch_gold"]                      =  495,
            ["pocket_watch_silver"]                    =  65,
            ["goldwatch"]                              = 125,

            ["aring"]                                  = 140,
            ["dring"]                                  = 140,
            ["ering"]                                  = 140,
            ["rring"]                                  = 175,
            ["sring"]                                  = 175,

            ["goldtooth"]                              = 160,

            ["pocket_compass"]                         =  690,
            ["provision_bracelet_gold"]                = 265,
            ["provision_bracelet_platinum"]             = 180,
            ["provision_bracelet_silver"]               = 265,
            ["provision_buckle_gold"]                   = 570,
            ["provision_buckle_platinum"]               = 185,
            ["provision_buckle_silver"]                 =  80,

            ["provision_earring_gold"]                  = 355,
            ["provision_earring_dutchess_emerald"]      = 595,
            ["provision_earring_endicott_diamond"]      = 700,
            ["provision_earring_orchidee_diamond"]      = 210,
            ["provision_earring_royal_victoria_diamond"]= 1325,
            ["provision_earring_silver"]                =  165,
            ["provision_earring_silverball"]            =  490,
            ["provision_earring_sterling_tooth"]        =  95,

            ["provision_necklace_gold_ring"]            = 175,
            ["provision_necklace_gold_cross_ainsworth"] = 365,
            ["provision_necklace_ruby"]                 = 420,
            ["provision_necklace_ruby_richelieu"]       = 200,

            ["provision_ring_beaulieux_diamond"]        = 410,
            ["provision_ring_bosque_emerald"]           = 325,
            ["provision_ring_silver"]                   =  160,
            ["provision_wedding_ring"]                  =  850,
            ["provision_signet_ring"]                   =  255,

            ["provision_penelopes_bracelet"]            =  440,
            ["provision_penelopes_necklace"]            =  745,
            ["provision_silver_wedding_chain_ring"]     =  180,

            ["ruby"]                                    = 90,
            ["sapphire"]                                = 95,
            ["diamondcut"]                              = 95,
            ["em"]                                      = 80,

            ["rubis"]                                   =  21,
            ["sap"]                                     =  22,
            ["diamond"]                                 =  25,
            ["emerald"]                                 =  24,
        },
    },
 --[[   -------------------------------------------------
    -- 4) Pawn Broker
    -------------------------------------------------
    {
        name     = 'Pawn Broker',
        coords       = vector3(-4216.20, -3450.88, 37.07),
        heading      = -32.012,
        promptCoords = vector3(-4216.20, -3450.88, 37.07), -- Move in front of counter
        blipName = 'Pawn Broker',
        ItemPrices = {
            ["smallnugget"]  = 12,
            ["mediumnugget"] = 17,
            ["largenugget"]  = 34,
            ["goldbar"]      = 550,
            ["halfeagle"]    = 100,
            ["bankbond"]     = 3000,
        },
    },
	--]]
  --[[  -------------------------------------------------
    -- 5) The Gun Dealer
    -------------------------------------------------
    {
        name     = 'The Gun Dealer',
        coords       = vector3(315.79, 1492.04, 181.28),
        heading      = 130.50,
        promptCoords = vector3(315.79, 1492.04, 181.28), -- Move in front of counter
        blipName = 'Gun Dealer',
        ItemPrices = {
            ["weapon_revolver_cattleman"]            = 140,
            ["weapon_revolver_cattleman_mexican"]    = 160,
            ["weapon_revolver_doubleaction_gambler"] = 140,
            ["weapon_revolver_schofield"]            = 140,
            ["weapon_revolver_lemat"]                = 140,
            ["weapon_revolver_navy"]                 = 160,
            ["weapon_revolver_navy_crossover"]       = 140,
            ["weapon_pistol_volcanic"]               = 140,
            ["weapon_pistol_m1899"]                  = 140,
            ["weapon_pistol_mauser"]                 = 140,
            ["weapon_pistol_semiauto"]               = 140,
            ["weapon_repeater_carbine"]              = 200,
            ["weapon_repeater_winchester"]           = 200,
            ["weapon_repeater_henry"]                = 200,
            ["weapon_repeater_evans"]                = 200,
            ["weapon_rifle_varmint"]                 = 150,
            ["weapon_rifle_springfield"]             = 200,
            ["weapon_rifle_boltaction"]              = 200,
            ["weapon_rifle_elephant"]                = 200,
            ["weapon_shotgun_doublebarrel"]          = 200,
            ["weapon_shotgun_doublebarrel_exotic"]   = 200,
            ["weapon_shotgun_sawedoff"]              = 190,
            ["weapon_shotgun_semiauto"]              = 200,
            ["weapon_shotgun_pump"]                  = 200,
            ["weapon_shotgun_repeating"]             = 200,
            ["weapon_sniperrifle_rollingblock"]      = 250,
            ["weapon_sniperrifle_carcano"]           = 250,
            ["weapon_bow"]                           = 125,
            ["weapon_bow_improved"]                  = 125,
        },
    },

    --]]
    -------------------------------------------------
    -- 6) The Guarma Vendor
    -------------------------------------------------
    {
        name     = 'The Guarma Vendor',
        coords       = vector3(1284.16, -6871.73, 43.4),
        heading      = 0.0,
        promptCoords = vector3(1284.16, -6871.73, 43.4), -- Move in front of counter
        blipName = 'Guarma Vendor',
        ItemPrices = {
            ["corn"]        = 2,
            ["wheat"]       = 2,
            ["sugar"]       = 2,
            ["tobacco"]     = 4,
            ["indtobacco"]  = 4,
            ["carrot"]      = 2,
            ["tomato"]      = 2,
            ["broccoli"]    = 2,
            ["potato"]      = 2,
            ["cotton"]      = 2,
            ["banana"]      = 5,
            ["coconut"]     = 5,
            ["mango"]       = 5,
            ["melon"]       = 5,
            ["kiwi"]        = 5,
            ["pineapple"]   = 5,
            ["orange"]      = 5,
            ["lemon"]       = 5,
            ["hay"]         = 1,
            ["egg"]         = 0.01,
            ["haybale"]     = 10,
            ["crayfish"]    = 2,
            ["bluecrab"]    = 3,
            ["carrotbox"]   = 50,
            ["cornsack"]    = 50,
            ["wheatsack"]   = 50,
            ["sugarsack"]   = 60,
            ["applesbox"]   = 60,
            ["tomatobox"]   = 50,
            ["broccolibox"] = 50,
            ["potatobox"]   = 50,
        },
    },
    -------------------------------------------------
    -- 7) The Mining Vendor
    -------------------------------------------------
    {
        name     = 'The Mining Vendor',
        coords       = vector3(2435.36, -1511.59, 45.97),
        heading      = 30.00,
        promptCoords = vector3(2435.36, -1511.59, 45.97), -- Move in front of counter
        blipName = 'Mining Vendor',
        ItemPrices = {
            ["copperore"]    = 1.50,
            ["copper_bar"]   = 10.50,
            ["aluminum"]     = 1.20,
            ["aluminum_bar"] = 10.50,
            ["ironore"]      = 1.50,
            ["iron_bar"]     = 10.50,
            ["steel"]        = 2.00,
            ["steel_bar"]    = 15.50,
            ["leadore"]      = 2.00,
            ["lead_bar"]     = 11.50,
            ["coal"]         = 2.00,
            ["stone"]        = 1.50,
            ["wood"]         = 0.03,   -- the general store sells wood for $0.06
        },
    },
    -------------------------------------------------
    -- 8) The Fossil Vendor
    -------------------------------------------------
    {
        name     = 'The Fossil Vendor',
        coords       = vector3(2632.21, -1364.70, 48.97),
        heading      = 304.13,
        promptCoords = vector3(2632.21, -1364.70, 48.97), -- Move in front of counter
        blipName = 'Fossil Vendor',
        ItemPrices = {
            ["arrowhead_bone"]              = 50.00,
            ["dinosaur_egg"]                = 100.00,
            ["finger_bone"]                 = 50.00,
            ["fossil_bivalve"]              = 20.00,
            ["fossil_brachiopod"]           = 20.00,
            ["fossil_brow_horn"]            = 10.00,
            ["fossil_cephalopod"]           = 20.00,
            ["fossil_coral"]                = 20.00,
            ["fossil_neo"]                  = 10.00,
            ["fossil_old"]                  = 20.00,
            ["fossil_pet_wood"]             = 20.00,
            ["fossil_pet_wood_rainbow"]     = 20.00,
            ["fossil_pet_wood_yellow_cat"]  = 10.00,
            ["fossil_sea_lily"]             = 20.00,
            ["fossil_sea_scorpion"]         = 20.00,
            ["fossil_stone"]                = 10.00,
            ["fossil_tail_spike"]           = 40.00,
            ["fossil_toe_claw"]             = 20.00,
            ["fossil_tooth_mega"]           = 20.00,
            ["fossil_tooth_serrated"]       = 10.00,
            ["fossil_tooth_tyrannosaur"]    = 100.00,
            ["fossil_trilobit"]             = 20.00,
            ["fossil_trilobite_crypto"]     = 40.00,
        },
    },
    -------------------------------------------------
    -- 9) The Witch Doctor
    -------------------------------------------------
    {
        name     = 'The Witch Doctor',
        coords       = vector3(2718.49, -1227.08, 49.36),
        heading      = 0.0,
        promptCoords = vector3(2718.49, -1227.08, 49.36), -- Move in front of counter
        blipName = 'Witch Doctor',
        ItemPrices = {
            ["tooth_aligatorto"]   = 1.50,
            ["tooth_beart"]        = 1.50,
            ["tooth_cougarf"]      = 1.50,
            ["tooth_coyotef"]      = 1.50,
            ["tooth_foxt"]         = 1.50,
            ["tooth_raccoont"]     = 1.50,
            ["tooth_snaket"]       = 1.50,
            ["tooth_turtlet"]      = 1.50,
            ["tooth_wolftooth"]    = 1.50,
            ["tooth_boarmusk"]     = 1.50,
            ["claws_armadilloc"]   = 1.00,
            ["claws_beartc"]       = 2.00,
            ["claws_cockc"]        = 2.00,
            ["claws_eaglet"]       = 7.00,
            ["claws_hawkt"]        = 2.00,
            ["claws_opossumc"]     = 7.00,
            ["claws_owlt"]         = 7.00,
            ["claws_ravenc"]       = 0.50,
            ["fiber_woolblack"]    = 1.00,
            ["tail_bull"]          = 3.00,
            ["wool"]               = 2.00,
            ["feathers"]           = 0.01,
            ["horn_bison"]         = 1.00,
            ["horn_bull"]          = 1.00,
            ["horn_cowh"]          = 1.00,
            ["horn_ox"]            = 1.00,
            ["horn_prong"]         = 1.00,
            ["horn_ram"]           = 1.00,
            ["horn_buckantler"]    = 1.00,
            ["horn_elkantler"]     = 1.00,
            ["tail_fox"]           = 1.00,
            ["tail_beaver"]        = 1.00,
            ["tail_chipmunk_c"]    = 1.00,
            ["tail_panthere"]      = 1.00,
            ["tail_lizardl"]       = 1.00,
            ["tail_rabbitpaw"]     = 1.00,
            ["beak_bparrotf"]      = 1.50,
            ["beak_quailb"]        = 1.50,
            ["beak_bbirdf"]        = 1.50,
            ["beak_boobyf"]        = 1.50,
            ["beak_daruf"]         = 1.50,
            ["beak_condorf"]       = 1.50,
            ["beak_pelicanf"]      = 1.50,
            ["beak_peasantf"]      = 1.50,
            ["beak_loonf"]         = 1.50,
            ["copper"]             = 1.50,
            ["beak_kbirdf"]        = 1.50,
            ["beak_goosef"]        = 1.50,
            ["beak_egretf"]        = 1.50,
            ["beak_turkeyf"]       = 1.50,
            ["beak_seagullf"]      = 1.50,
            ["beak_rspoonf"]       = 1.50,
            ["beak_prairif"]       = 1.50,
            ["beak_chickenf"]      = 1.50,
            ["beak_eaglef"]        = 1.50,
            ["beak_hawkf"]         = 1.50,
            ["beak_owlf"]          = 1.50,
            ["beak_ravenf"]        = 1.50,
            ["beak_duckf"]         = 1.50,
            ["beak_vulturef"]      = 1.50,
        },
    },
}