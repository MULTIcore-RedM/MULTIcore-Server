-- ============================================================
-- MULTIhunting :: what each animal gives when it is skinned
-- Keyed by ped model name (the hash is worked out at start).
--   pelt   the skin / pelt / hide item. A string = that item, carrying info.quality from
--          Config.Quality.Percent (MULTIstores pays price x quality / 100).
--          A table { poor = '...', good = '...', perfect = '...' } = a different item per grade.
--   meat   how many Config.MeatItem (raw_meat) the animal gives (0 / nil = none)
--   meatItem  a different meat item for this animal (optional)
--   parts  extra items, each given once: 'item' or { 'item', amount }
--   whole  small game: the whole animal is the item (no pelt, no quality)
--   legendary  true = the pelt is always perfect
--
-- Item names are the ones MULTIstores' trappers and butchers buy (config/products.lua),
-- most of them taken from rsg-hunting's animal list (RSG v2, GPL v3, see CREDITS.md).
-- Unknown models give nothing.
-- ============================================================

Config.Animals = {
    -- big game
    a_c_alligator_01   = { pelt = 'resource_skin_alligator', meatItem = 'consumable_meat_alligator', meat = 1, parts = { 'resource_tooth_alligator' } },
    a_c_alligator_03   = { pelt = 'resource_skin_alligator', meatItem = 'consumable_meat_alligator', meat = 1, parts = { 'resource_tooth_alligator' } },
    a_c_bear_01        = { pelt = 'resource_skin_bear',       meat = 3, parts = { 'resource_tooth_bear', 'heart_bear' } },
    a_c_bearblack_01   = { pelt = 'resource_skin_bear_black', meat = 3, parts = { 'resource_tooth_bear', 'heart_bear' } },
    a_c_bighornram_01  = { pelt = 'resource_skin_ram',        meat = 2, parts = { 'resource_horn_ram' } },
    a_c_boar_01        = { pelt = 'resource_skin_boar',       meat = 2, parts = { 'heart_pig_boar', 'resource_tusk_boar' } },
    a_c_buck_01        = { pelt = 'resource_skin_buck',       meat = 2, parts = { 'resource_antler_buck' } },
    a_c_buffalo_01     = { pelt = 'resource_skin_buffalo',    meat = 3, parts = { 'resource_horn_buffalo' } },
    a_c_cougar_01      = { pelt = 'resource_skin_cougar',     meat = 2, parts = { 'heart_cougar', 'resource_tooth_cougar' } },
    a_c_deer_01        = { pelt = 'resource_skin_deer',       meat = 2 },
    a_c_elk_01         = { pelt = 'resource_skin_elk',        meat = 3, parts = { 'resource_antler_elk' } },
    a_c_javelina_01    = { pelt = 'resource_skin_javelina_boar', meat = 1, parts = { 'resource_tusk_javolina' } },
    a_c_moose_01       = { pelt = 'resource_skin_moose',      meat = 3, parts = { 'resource_antler_moose' } },
    a_c_panther_01     = { pelt = 'resource_skin_panther',    meat = 2, parts = { 'resource_claw_panther', 'heart_panther', 'resource_panthereye' } },
    a_c_pronghorn_01   = { pelt = 'resource_skin_pronghorn',  meat = 2, parts = { 'resource_horn_pronghorn' } },

    -- predators and medium game
    a_c_coyote_01      = { pelt = 'resource_pelt_coyote',     meat = 1, parts = { 'resource_tooth_coyote' } },
    a_c_fox_01         = { pelt = 'resource_pelt_fox',        meat = 1, parts = { 'resource_tooth_fox' } },
    a_c_wolf           = { pelt = 'resource_pelt_wolf',       meat = 1, parts = { 'resource_tooth_wolf', 'heart_wolf' } },
    a_c_wolf_medium    = { pelt = 'resource_pelt_wolf',       meat = 1, parts = { 'resource_tooth_wolf', 'heart_wolf' } },
    a_c_wolf_small     = { pelt = 'resource_pelt_wolf',       meat = 1, parts = { 'resource_tooth_wolf', 'heart_wolf' } },
    a_c_badger_01      = { pelt = 'resource_pelt_badger',     meat = 1 },
    a_c_beaver_01      = { pelt = 'resource_pelt_beaver',     meat = 1, parts = { 'resource_tail_beaver' } },
    a_c_muskrat_01     = { pelt = 'resource_pelt_muskrat' },
    a_c_rabbit_01      = { pelt = 'resource_pelt_rabbit',     meat = 1, parts = { 'resource_foot_rabbit' } },
    a_c_raccoon_01     = { pelt = 'resource_pelt_raccoon',    meat = 1, parts = { 'resource_tooth_raccoon' } },
    a_c_skunk_01       = { pelt = 'resource_pelt_skunk' },

    -- livestock
    a_c_bull_01        = { pelt = 'resource_hide_cow_bull',   meat = 3, parts = { 'resource_horn_bull' } },
    a_c_cow            = { pelt = 'resource_hide_cow1',       meat = 3, parts = { 'resource_horn_cow' } },
    a_c_goat_01        = { pelt = 'resource_skin_goat',       meat = 1, parts = { 'resource_head_goat' } },
    a_c_ox_01          = { pelt = 'resource_hide_cow_ox',     meat = 3, parts = { 'resource_horn_ox' } },
    a_c_pig_01         = { pelt = 'resource_skin_pig',        meat = 2, parts = { 'pigs_feet' } },
    a_c_sheep_01       = { pelt = 'resource_wool',            meat = 1, parts = { 'resource_head_sheep' } },

    -- reptiles
    a_c_gilamonster_01          = { pelt = 'resource_skin_gilamonster' },
    a_c_iguana_01               = { pelt = 'resource_skin_iguana' },
    a_c_iguanadesert_01         = { pelt = 'resource_skin_desert_iguana' },
    a_c_snake_01                = { pelt = 'resource_skin_snake_western_rattlesnake', parts = { 'resource_tooth_snake' } },
    a_c_snakeblacktailrattle_01 = { pelt = 'resource_skin_snake_blacktail_rattlesnake', parts = { 'resource_tooth_snake' } },
    a_c_snakeferdelance_01      = { pelt = 'resource_skin_snake_ferdelance', parts = { 'resource_tooth_snake' } },
    a_c_snakeredboa_01          = { pelt = 'resource_skin_snake_boa', parts = { 'resource_tooth_snake' } },
    a_c_snakeredboa10ft_01      = { pelt = 'resource_skin_snake_boa', parts = { 'resource_tooth_snake' } },
    a_c_snakewater_01           = { pelt = 'resource_skin_snake_watersnake', parts = { 'resource_tooth_snake' } },
    a_c_turtlesea_01            = { pelt = 'resource_shell_turtle', parts = { 'provision_beak_turtle' } },
    a_c_turtlesnapping_01       = { pelt = 'resource_shell_turtle', parts = { 'provision_beak_turtle' } },

    -- birds that are plucked
    a_c_californiacondor_01 = { parts = { 'provision_feather_condor', 'provision_beak_condor' } },
    a_c_chicken_01          = { meat = 1, parts = { 'heart_chicken', 'provision_feather_chicken' } },
    a_c_cormorant_01        = { parts = { 'provision_feather_cormorant', 'provision_beak_cormorant' } },
    a_c_cranewhooping_01    = { parts = { 'provision_feather_crane', 'provision_beak_crane' } },
    a_c_duck_01             = { meat = 1, parts = { 'heart_duck', 'feather' } },
    a_c_eagle_01            = { parts = { 'provision_feather_eagle', 'resource_claw_eagle' } },
    a_c_egret_01            = { parts = { 'provision_feather_egret', 'provision_beak_egret' } },
    a_c_goosecanada_01      = { meat = 1, parts = { 'provision_feather_goose', 'provision_beak_goose' } },
    a_c_hawk_01             = { parts = { 'provision_feather_hawk', 'resource_claw_hawk' } },
    a_c_heron_01            = { parts = { 'provision_feather_heron', 'provision_beak_heron' } },
    a_c_loon_01             = { parts = { 'provision_feather_loon', 'provision_beak_common_loon' } },
    a_c_owl_01              = { parts = { 'provision_feather_owl', 'resource_claw_owl' } },
    a_c_parrot_01           = { parts = { 'provision_feather_parrot', 'provision_beak_parrot' } },
    a_c_pelican_01          = { parts = { 'provision_feather_pelican', 'provision_beak_pelican' } },
    a_c_pheasant_01         = { meat = 1, parts = { 'provision_feather_pheasant', 'provision_beak_phesant' } },
    a_c_prairiechicken_01   = { meat = 1, parts = { 'provision_feather_prairie_chicken', 'provision_beak_prairie_chicken', 'heart_chicken' } },
    a_c_raven_01            = { parts = { 'provision_feather_raven', 'resource_claw_raven' } },
    a_c_redfootedbooby_01   = { parts = { 'provision_feather_red_footed_booby', 'provision_beak_red_footed_booby' } },
    a_c_rooster_01          = { parts = { 'provision_feather_rooster', 'resource_claw_rooster' } },
    a_c_roseatespoonbill_01 = { parts = { 'provision_feather_roseta_spoonbill', 'provision_beak_roseate_spoonbill' } },
    a_c_seagull_01          = { parts = { 'provision_feather_seagull', 'provision_beak_seagull' } },
    a_c_turkey_01           = { meat = 1, parts = { 'provision_feather_turkey', 'provision_beak_turkey', 'heart_turkey' } },
    a_c_turkey_02           = { meat = 1, parts = { 'provision_feather_turkey', 'provision_beak_turkey', 'heart_turkey' } },
    a_c_turkeywild_01       = { meat = 1, parts = { 'provision_feather_turkey', 'provision_beak_turkey', 'heart_turkey' } },
    a_c_vulture_01          = { parts = { 'provision_feather_vulture', 'provision_beak_vulture' } },

    -- small game, kept whole (sold whole at the butcher or the trapper)
    a_c_armadillo_01        = { whole = 'a_c_armadillo_01' },
    a_c_bat_01              = { whole = 'a_c_bat_01' },
    a_c_bluejay_01          = { whole = 'a_c_bluejay_01' },
    a_c_cardinal_01         = { whole = 'a_c_cardinal_01' },
    a_c_carolinaparakeet_01 = { whole = 'a_c_carolinaparakeet_01' },
    a_c_cedarwaxwing_01     = { whole = 'a_c_cedarwaxwing_01' },
    a_c_chipmunk_01         = { whole = 'a_c_chipmunk_01' },
    a_c_crab_01             = { whole = 'a_c_crab_01' },
    a_c_crow_01             = { whole = 'a_c_crow_01' },
    a_c_frogbull_01         = { whole = 'a_c_frogbull_01' },
    a_c_oriole_01           = { whole = 'a_c_oriole_01' },
    a_c_pigeon              = { whole = 'a_c_pigeon' },
    a_c_possum_01           = { whole = 'a_c_possum_01' },
    a_c_quail_01            = { whole = 'a_c_quail_01' },
    a_c_rat_01              = { whole = 'a_c_rat_01' },
    a_c_robin_01            = { whole = 'a_c_robin_01' },
    a_c_songbird_01         = { whole = 'a_c_songbird_01' },
    a_c_sparrow_01          = { whole = 'a_c_sparrow_01' },
    a_c_squirrel_01         = { whole = 'a_c_squirrel_01' },
    a_c_toad_01             = { whole = 'a_c_toad_01' },
    a_c_woodpecker_01       = { whole = 'a_c_woodpecker_01' },
    a_c_woodpecker_02       = { whole = 'a_c_woodpecker_02' },

    -- legendary
    a_c_alligator_02        = { pelt = 'resource_skin_alligator_legendary', legendary = true, meatItem = 'consumable_meat_alligator', meat = 1, parts = { 'resource_tooth_alligator', 'resource_bullgatoreye' } },
    a_c_boarlegendary_01    = { pelt = 'resource_skin_boar_legendary', legendary = true, meat = 2, parts = { 'heart_pig_boar', 'resource_tusk_boar' } },
    a_c_buffalo_tatanka_01  = { pelt = 'resource_skin_buffalo_legendary', legendary = true, meat = 3, parts = { 'resource_horn_buffalo' } },
}
