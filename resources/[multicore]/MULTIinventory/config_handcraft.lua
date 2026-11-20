-- ============================================================
-- MULTIinventory :: hand crafting (the "Craft" tab of the inventory)
--
-- Simple things a person can make with their hands, anywhere, no bench:
-- rolling a cigarette, tearing a bandage, twisting twine. The server
-- recomputes every recipe, takes the ingredients and gives the result in one
-- step (rolled back if anything fails or there is no room).
--
-- Other resources add their own recipes at runtime:
--   exports.MULTIinventory:RegisterHandRecipe(id, data)   (same shape as below)
--   exports.MULTIinventory:RemoveHandRecipe(id)
--   exports.MULTIinventory:GetHandRecipes()
-- ============================================================

Config = Config or {}

Config.HandCraft = {
    enabled = true,

    maxQuantity = 20,          -- most crafts in one go (a recipe may set a lower maxQuantity)
    repeatFactor = 0.6,        -- each extra craft in a batch takes time * repeatFactor
    maxDurationMs = 45000,     -- a batch never takes longer than this
    minIntervalMs = 1500,      -- per player: time between two craft starts (anti-spam)
    minElapsedRatio = 0.9,     -- the finish must arrive after at least 90 % of the progress time
    lockTimeoutMs = 15000,     -- a craft nobody finished is forgotten this long after it should have ended
    maxMoveDistance = 3.0,     -- metres the server lets the player drift between start and finish
    cancelDistance = 0.8,      -- client: moving this far cancels the craft

    showUnavailable = true,    -- also list recipes missing two or more things (greyed, at the bottom)
    log = true,                -- write each craft to the audit log (multiinv_log, action 'craft')

    -- Animation used when a recipe sets none. Only well-known RDR2 dictionaries; the client checks the
    -- dictionary exists and loads within anim.loadTimeoutMs, otherwise the craft runs without animation.
    -- flag 31 = upper body, looped, the player keeps control (walking away cancels the craft).
    defaultAnim = { dict = 'mech_inventory@crafting@fallbacks', clip = 'full_craft_and_stow', flag = 31 },
    animLoadTimeoutMs = 1500,

    -- Optional skills (off). When enabled, a recipe with skill = { name = 'x', level = n } asks
    -- getLevel(src, name) and needs a level >= n. Wire it to your skill script here.
    skill = {
        enabled = false,
        getLevel = function(src, name) return 0 end,
    },

    -- --------------------------------------------------------
    -- Recipes. Key = recipe id.
    --   label, description, category       text shown in the Craft tab
    --   ingredients = { { items = { 'a', 'b' }, count = 1, label = 'Tobacco' }, { item = 'c', count = 2 } }
    --                                       items = alternatives (the first one carried is used first)
    --   tools = { { item = 'knife' } }      needed but kept (same shape as ingredients)
    --   outputs = { { item = 'x', count = 1, metadata = { ... } } }
    --   time = ms for one craft             anim = { dict, clip, flag } | { scenario = 'WORLD_HUMAN_...' } | false
    --   jobs = { 'doctor', valmedic = 2 }    job names (= any grade) or name = min grade; '^...' = Lua pattern
    --   knownItem = 'item'                  must be carried (a recipe book / guide), never used up
    --   skill = { name = 'crafting', level = 2 }   only when Config.HandCraft.skill.enabled
    --   cooldown = seconds after a craft    maxQuantity = n    enabled = false to switch one off
    --   station = 'spinning_wheel'|'mortar'|...  needs that station nearby (config_workshop.lua Config.Stations)
    --   unlock = 'recipe_item'              locked until the player reads that recipe book (Config.CraftBook.recipeBooks)
    -- Every item below exists in the live `items` table (checked 2026-10-09; Spinning & Sewing and
    -- Apothecary 2026-10-15 - thread, yarn, wool_scarf, wool_blanket, sewing_kit are new, see install/).
    -- --------------------------------------------------------
    recipes = {
        roll_cigarette = {
            label = 'Roll a Cigarette',
            description = 'A pinch of tobacco rolled in a paper by hand.',
            category = 'Tobacco',
            ingredients = {
                { items = { 'dried_tobacco', 'tobacco', 'tobacco_leaf' }, count = 1, label = 'Tobacco' },
                { items = { 'rollingpaper', 'rollingpapers' }, count = 1, label = 'Rolling paper' },
            },
            outputs = { { item = 'cigarette', count = 1 } },
            time = 4500,
        },
        roll_cigarette_tipped = {
            label = 'Roll a Cork-Tipped Cigarette',
            description = 'Rolled by hand around a cork tip, the way the dandies smoke them.',
            category = 'Tobacco',
            ingredients = {
                { items = { 'dried_tobacco', 'tobacco', 'tobacco_leaf' }, count = 1, label = 'Tobacco' },
                { items = { 'rollingpaper', 'rollingpapers' }, count = 1, label = 'Rolling paper' },
                { item = 'cigarettefilter', count = 1 },
            },
            outputs = { { item = 'cigarette', count = 1,
                          metadata = { label = 'Cork-Tipped Cigarette', description = 'Hand-rolled around a cork tip.' } } },
            time = 5500,
        },
        pack_cigarettes = {
            label = 'Pack Cigarettes',
            description = 'Fold a paper packet around ten loose cigarettes.',
            category = 'Tobacco',
            ingredients = {
                { item = 'cigarette', count = 10 },
                { item = 'paper', count = 1 },
            },
            outputs = { { item = 'cigarette_pack', count = 1 } },
            time = 5000,
            maxQuantity = 5,
        },
        open_cigarette_pack = {
            label = 'Open a Pack of Cigarettes',
            description = 'Tear the packet open: ten cigarettes.',
            category = 'Tobacco',
            ingredients = { { item = 'cigarette_pack', count = 1 } },
            outputs = { { item = 'cigarette', count = 10 } },
            time = 2500,
            maxQuantity = 2,
        },
        tear_bandage = {
            label = 'Tear a Bandage',
            description = 'Tear a clean cloth into a strip for binding a wound.',
            category = 'Remedies',
            ingredients = { { item = 'clean_cloth', count = 1 } },
            outputs = { { item = 'bandage', count = 1 } },
            time = 4000,
        },
        tear_bandage_rag = {
            label = 'Tear a Rag Bandage',
            description = 'Two pieces of plain cloth torn and folded into a rough bandage.',
            category = 'Remedies',
            ingredients = { { item = 'cloth', count = 2 } },
            outputs = { { item = 'bandage', count = 1 } },
            time = 5000,
        },
        wash_cloth = {
            label = 'Wash a Cloth',
            description = 'Rinse and wring a cloth in clean water.',
            category = 'Remedies',
            ingredients = {
                { item = 'cloth', count = 1 },
                { item = 'water', count = 1 },
            },
            outputs = { { item = 'clean_cloth', count = 1 } },
            time = 6000,
        },
        twist_twine = {
            label = 'Twist Twine',
            description = 'Twist plant fibre between the palms into a length of twine.',
            category = 'Materials',
            ingredients = { { items = { 'fiber', 'fibers' }, count = 3, label = 'Fibre' } },
            outputs = { { item = 'twine', count = 1 } },
            time = 6000,
        },
        lay_rope = {
            label = 'Lay a Rope',
            description = 'Braid four lengths of twine into a short rope. Slow work by hand.',
            category = 'Materials',
            ingredients = { { item = 'twine', count = 4 } },
            outputs = { { item = 'rope', count = 1 } },
            time = 9000,
            maxQuantity = 5,
        },
        cut_bait = {
            label = 'Cut Fishing Bait',
            description = 'Cut tough, stringy meat into strips for the hook.',
            category = 'Provisions',
            ingredients = { { item = 'stringy', count = 1 } },
            outputs = { { item = 'fishing_bait', count = 2 } },
            time = 4000,
        },

        -- ---------------- Spinning & Sewing (spinning wheel; needle work) ----------------
        spin_yarn = {
            label = 'Spin Yarn',
            description = 'Card the wool and spin it into a soft yarn.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { items = { 'wool', 'resource_wool' }, count = 2, label = 'Wool' } },
            outputs = { { item = 'yarn', count = 2 } },
            time = 7000,
        },
        spin_thread = {
            label = 'Spin Thread',
            description = 'Plant fibre or cotton drawn out fine and spun into thread.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { items = { 'cotton', 'fiber', 'fibers' }, count = 3, label = 'Cotton or fibre' } },
            outputs = { { item = 'thread', count = 2 } },
            time = 7000,
        },
        twist_string = {
            label = 'Twist String',
            description = 'Two threads plied together on the wheel into a strong string.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { item = 'thread', count = 2 } },
            outputs = { { item = 'string', count = 1 } },
            time = 5000,
        },
        spin_rope = {
            label = 'Spin a Rope',
            description = 'Hemp or fibre spun and laid into rope - far quicker than by hand.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { items = { 'hemp', 'fiber', 'fibers' }, count = 6, label = 'Hemp or fibre' } },
            outputs = { { item = 'rope', count = 1 } },
            time = 9000,
            maxQuantity = 5,
        },
        weave_cloth = {
            label = 'Weave Cloth',
            description = 'Thread woven into a plain square of cloth.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { item = 'thread', count = 3 } },
            outputs = { { item = 'cloth', count = 1 } },
            time = 8000,
        },
        weave_burlap = {
            label = 'Weave Burlap',
            description = 'Coarse hemp or fibre woven loose into burlap.',
            category = 'Spinning & Sewing', station = 'spinning_wheel',
            ingredients = { { items = { 'hemp', 'fiber', 'fibers' }, count = 4, label = 'Hemp or fibre' } },
            outputs = { { item = 'burlap', count = 1 } },
            time = 8000,
        },
        sew_bandages = {
            label = 'Sew Bandages',
            description = 'Clean cloth cut into strips and hemmed so they do not fray.',
            category = 'Spinning & Sewing',
            ingredients = { { item = 'clean_cloth', count = 1 }, { item = 'thread', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'bandage', count = 2 } },
            time = 6000,
        },
        sew_fine_bandages = {
            label = 'Sew Fine Bandages',
            description = 'Folded, double-stitched dressings a doctor would be glad of.',
            category = 'Spinning & Sewing', unlock = 'recipe_tailoring',
            ingredients = { { item = 'clean_cloth', count = 2 }, { item = 'thread', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'bandagecool', count = 2 } },
            time = 8000,
        },
        sew_burlap_sack = {
            label = 'Sew a Burlap Sack',
            description = 'Two lengths of burlap stitched with string into a sack.',
            category = 'Spinning & Sewing',
            ingredients = { { item = 'burlap', count = 2 }, { item = 'string', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'sacks', count = 1 } },
            time = 7000,
        },
        knit_wool_scarf = {
            label = 'Knit a Wool Scarf',
            description = 'A long warm scarf for the northern passes.',
            category = 'Spinning & Sewing', unlock = 'recipe_knitting',
            ingredients = { { item = 'yarn', count = 4 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'wool_scarf', count = 1 } },
            time = 15000,
            maxQuantity = 5,
        },
        knit_wool_blanket = {
            label = 'Knit a Wool Blanket',
            description = 'Heavy wool on a cloth backing - keeps the cold off at camp.',
            category = 'Spinning & Sewing', unlock = 'recipe_knitting',
            ingredients = { { item = 'yarn', count = 10 }, { item = 'cloth', count = 2 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'wool_blanket', count = 1 } },
            time = 25000,
            maxQuantity = 2,
        },
        stitch_leather_belt = {
            label = 'Stitch a Leather Belt',
            description = 'Leather cut to a strap and saddle-stitched along the edge.',
            category = 'Spinning & Sewing', unlock = 'recipe_tailoring',
            ingredients = { { item = 'leather', count = 2 }, { item = 'thread', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'leather_belt', count = 1 } },
            time = 12000,
            maxQuantity = 5,
        },
        make_sewing_kit = {
            label = 'Make a Sewing Kit',
            description = 'Needles and a good roll of thread in a leather wallet.',
            category = 'Spinning & Sewing', unlock = 'recipe_tailoring',
            ingredients = { { item = 'needle', count = 2 }, { item = 'thread', count = 4 }, { item = 'leather', count = 1 } },
            outputs = { { item = 'sewing_kit', count = 1 } },
            time = 9000,
            maxQuantity = 3,
        },

        -- ---------------- Apothecary (mortar & pestle) ----------------
        -- Herbs: RINGOherbs gives consumable_herb_*; the herb_* names are other scripts' versions.
        grind_herb_mix = {
            label = 'Grind a Herb Mix',
            description = 'Any three wild herbs ground together - the base of most remedies.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_yarrow', 'consumable_herb_wild_mint', 'consumable_herb_creeping_thyme',
                                        'consumable_herb_oregano', 'consumable_herb_red_sage', 'consumable_herb_desert_sage',
                                        'consumable_herb_hummingbird_sage', 'consumable_herb_burdock_root' }, count = 3, label = 'Wild herbs' } },
            outputs = { { item = 'herb_mix', count = 1 } },
            time = 6000,
        },
        mash_herbal_poultice = {
            label = 'Mash a Herbal Poultice',
            description = 'Yarrow pounded to a paste and wrapped in clean cloth.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_yarrow', 'herb_yarrow' }, count = 2, label = 'Yarrow' },
                            { item = 'clean_cloth', count = 1 } },
            outputs = { { item = 'herbal_poultice', count = 1 } },
            time = 7000,
        },
        mash_herbal_bandage = {
            label = 'Dress a Herbal Bandage',
            description = 'A bandage soaked in a paste of milkweed or yarrow.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { item = 'bandage', count = 1 },
                            { items = { 'consumable_herb_milkweed', 'herb_milkweed', 'consumable_herb_yarrow', 'herb_yarrow' }, count = 1, label = 'Milkweed or yarrow' } },
            outputs = { { item = 'bandage_herbal', count = 1 } },
            time = 6000,
        },
        brew_herbal_tonic = {
            label = 'Herbal Tonic',
            description = 'Ginseng root ground and steeped, then bottled.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_american_ginseng', 'consumable_herb_alaskan_ginseng', 'herb_american_ginseng', 'herb_alaskan_ginseng' }, count = 2, label = 'Ginseng' },
                            { item = 'water', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'herbal_tonic', count = 1 } },
            time = 9000,
        },
        brew_fever_tonic = {
            label = 'Fever Tonic',
            description = 'Feverfew ground fine and steeped in alcohol.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_wild_feverfew', 'herb_wild_feverfew' }, count = 2, label = 'Wild feverfew' },
                            { item = 'alcohol', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'fever_tonic', count = 1 } },
            time = 9000,
        },
        mix_burn_salve = {
            label = 'Burn Salve',
            description = 'Milkweed sap worked into warm beeswax.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_milkweed', 'herb_milkweed' }, count = 2, label = 'Milkweed' },
                            { items = { 'beeswax', 'wax' }, count = 1, label = 'Beeswax' } },
            outputs = { { item = 'burn_salve', count = 1 } },
            time = 8000,
        },
        mix_camphor_salve = {
            label = 'Camphor Salve',
            description = 'Wintergreen and mint pounded into animal fat - for aches and chests.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_wintergreen_berry', 'consumable_herb_wild_mint', 'herb_wild_mint' }, count = 2, label = 'Wintergreen or mint' },
                            { items = { 'Fat', 'beeswax' }, count = 1, label = 'Fat or beeswax' } },
            outputs = { { item = 'camphor_salve', count = 1 } },
            time = 8000,
        },
        brew_cough_syrup = {
            label = 'Cough Syrup',
            description = 'Wild mint crushed into honey and thinned with water.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_wild_mint', 'herb_wild_mint' }, count = 2, label = 'Wild mint' },
                            { items = { 'honey', 'bee_honey_jar' }, count = 1, label = 'Honey' },
                            { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'cough_syrup', count = 1 } },
            time = 8000,
        },
        grind_mint_tea = {
            label = 'Mint Tea',
            description = 'Bruised mint leaves steeped in hot water.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_wild_mint', 'herb_wild_mint' }, count = 1, label = 'Wild mint' }, { item = 'water', count = 1 } },
            outputs = { { item = 'consumable_tea_mint', count = 1 } },
            time = 5000,
        },
        grind_ginseng_tea = {
            label = 'Ginseng Tea',
            description = 'Ginseng root pounded and steeped.',
            category = 'Apothecary', station = 'mortar',
            ingredients = { { items = { 'consumable_herb_american_ginseng', 'consumable_herb_alaskan_ginseng', 'herb_american_ginseng', 'herb_alaskan_ginseng' }, count = 1, label = 'Ginseng' },
                            { item = 'water', count = 1 } },
            outputs = { { item = 'ginsengtea', count = 1 } },
            time = 5000,
        },
        mix_smelling_salts = {
            label = 'Smelling Salts',
            description = 'Dried sage ground sharp and wetted with alcohol. One sniff wakes the dead - nearly.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_apothecary',
            ingredients = { { items = { 'consumable_herb_red_sage', 'consumable_herb_desert_sage', 'consumable_herb_hummingbird_sage', 'herb_red_sage', 'herb_desert_sage' }, count = 2, label = 'Sage' },
                            { item = 'alcohol', count = 1 } },
            outputs = { { item = 'smelling_salts', count = 1 } },
            time = 9000,
        },
        brew_herbal_medicine = {
            label = 'Herbal Medicine',
            description = 'A strong herb mix steeped in alcohol and bottled.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_apothecary',
            ingredients = { { item = 'herb_mix', count = 1 }, { item = 'alcohol', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'herbal_medicine', count = 1 } },
            time = 10000,
        },
        brew_laudanum = {
            label = 'Laudanum',
            description = 'Poppy ground and steeped in alcohol. Strong stuff - mind the dose.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_apothecary',
            ingredients = { { items = { 'consumable_herb_prairie_poppy', 'herb_prairie_poppy', 'dried_poppy' }, count = 3, label = 'Prairie poppy' },
                            { item = 'alcohol', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'laudanum', count = 1 } },
            time = 12000,
            maxQuantity = 5,
        },

        -- ---------------- Loot-only: learned from a recipe page (robberies, NPC loot, written copies) ----------------
        craft_field_dressing = {
            label = 'Field Dressing',
            description = 'A bandage folded over a herbal poultice - the army way.',
            category = 'Remedies', unlock = 'recipe_page',
            ingredients = { { item = 'bandage', count = 1 }, { item = 'herbal_poultice', count = 1 } },
            outputs = { { item = 'fieldbandage', count = 1 } },
            time = 6000,
        },
        craft_honey_bandage = {
            label = 'Honey Bandage',
            description = 'A clean bandage spread with honey to keep the wound sweet.',
            category = 'Remedies', unlock = 'recipe_page',
            ingredients = { { item = 'bandage', count = 1 }, { items = { 'honey', 'bee_honey_jar' }, count = 1, label = 'Honey' } },
            outputs = { { item = 'honey_bandage', count = 1 } },
            time = 6000,
        },
        mix_horse_ointment = {
            label = 'Horse Ointment',
            description = 'Burdock and yarrow pounded into fat, for cuts on a horse\'s legs.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_page',
            ingredients = { { items = { 'consumable_herb_burdock_root', 'consumable_herb_yarrow', 'herb_burdock_root', 'herb_yarrow' }, count = 2, label = 'Burdock or yarrow' },
                            { items = { 'Fat', 'beeswax' }, count = 1, label = 'Fat or beeswax' } },
            outputs = { { item = 'consumable_horse_ointment', count = 1 } },
            time = 8000,
        },
        brew_snake_oil = {
            label = 'Snake Oil',
            description = 'Indian tobacco and oleander in cheap alcohol. Sells better than it cures.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_page',
            ingredients = { { items = { 'consumable_herb_indian_tobacco', 'consumable_herb_oleander_sage', 'herb_indian_tobacco', 'herb_oleander_sage' }, count = 2, label = 'Indian tobacco or oleander' },
                            { item = 'alcohol', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'snake_oil', count = 1 } },
            time = 9000,
        },
        brew_ginseng_elixir = {
            label = 'Ginseng Elixir',
            description = 'A strong ginseng tincture, three roots to the bottle.',
            category = 'Apothecary', station = 'mortar', unlock = 'recipe_page',
            ingredients = { { items = { 'consumable_herb_american_ginseng', 'consumable_herb_alaskan_ginseng', 'herb_american_ginseng', 'herb_alaskan_ginseng' }, count = 3, label = 'Ginseng' },
                            { item = 'alcohol', count = 1 }, { item = 'empty_bottle', count = 1 } },
            outputs = { { item = 'consumable_ginseng_elixier', count = 1 } },
            time = 12000,
            maxQuantity = 5,
        },
        sew_feedbag = {
            label = 'Sew a Feedbag',
            description = 'Burlap stitched into a nosebag with a rope strap.',
            category = 'Spinning & Sewing', unlock = 'recipe_page',
            ingredients = { { item = 'burlap', count = 2 }, { item = 'rope', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'feedbag', count = 1 } },
            time = 9000,
        },
        sew_saddle_blanket = {
            label = 'Sew a Saddle Blanket',
            description = 'Thick yarn on a cloth back, cut to sit under a saddle.',
            category = 'Spinning & Sewing', unlock = 'recipe_page',
            ingredients = { { item = 'yarn', count = 6 }, { item = 'cloth', count = 2 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'horse_blanket', count = 1 } },
            time = 18000,
            maxQuantity = 2,
        },
        sew_fur_blanket = {
            label = 'Sew a Fur Blanket',
            description = 'Pelts stitched together on a cloth lining. Worth a small fortune up north.',
            category = 'Spinning & Sewing', unlock = 'recipe_page',
            ingredients = { { items = { 'resource_pelt_rabbit', 'resource_pelt_fox', 'resource_pelt_coyote', 'resource_pelt_beaver', 'resource_pelt_raccoon' }, count = 3, label = 'Pelts' },
                            { item = 'cloth', count = 2 }, { item = 'thread', count = 2 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'fur_blanket', count = 1 } },
            time = 25000,
            maxQuantity = 2,
        },
        stitch_leather_satchel = {
            label = 'Stitch a Leather Satchel',
            description = 'A shoulder satchel of saddle-stitched leather.',
            category = 'Spinning & Sewing', unlock = 'recipe_page',
            ingredients = { { item = 'leather', count = 4 }, { item = 'thread', count = 2 }, { item = 'string', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'leather_satchel', count = 1 } },
            time = 20000,
            maxQuantity = 2,
        },

        -- ---------------- Outlaw's Craft: learned from Outlaw's Notes (robbery loot) or Rory Dolan's ----------------
        -- ---------------- "Tricks of the Trade" missions (RINGOnpcmissions). Never sold, never taught by a book. ----
        bend_lockpick = {
            label = 'Bend a Lockpick',
            description = 'Two nails hammered flat and bent into a pick and a tension wrench.',
            category = 'Outlaw\'s Craft', unlock = 'recipe_page_outlaw',
            ingredients = { { items = { 'iron_nail', 'nails' }, count = 2, label = 'Nails' } },
            tools = { { items = { 'hammer', 'toolhammer', 'ironhammer' }, label = 'Hammer' } },
            outputs = { { item = 'lockpick', count = 1 } },
            time = 8000,
            maxQuantity = 5,
        },
        cast_lockpicks = {
            label = 'Cast Lockpicks',
            description = 'Bar iron heated in the coals, poured into a lockpick mold and filed true. Three at a time.',
            category = 'Outlaw\'s Craft', station = 'campfire', unlock = 'recipe_page_outlaw',
            ingredients = { { items = { 'iron_ingot', 'ironbar', 'iron_bar' }, count = 1, label = 'Bar iron' },
                            { items = { 'coal', 'charcoal' }, count = 1, label = 'Coal or charcoal' } },
            tools = { { item = 'lockpickmold' }, { items = { 'hammer', 'toolhammer', 'ironhammer' }, label = 'Hammer' } },
            outputs = { { item = 'lockpick', count = 3 } },
            time = 15000,
            maxQuantity = 3,
        },
        cast_lockpick_mold = {
            label = 'Cast a Lockpick Mold',
            description = 'Iron poured around a good pick to make a mold that casts more of them.',
            category = 'Outlaw\'s Craft', station = 'campfire', unlock = 'recipe_page_outlaw',
            ingredients = { { items = { 'iron_ingot', 'ironbar', 'iron_bar' }, count = 2, label = 'Bar iron' },
                            { items = { 'coal', 'charcoal' }, count = 2, label = 'Coal or charcoal' },
                            { item = 'lockpick', count = 1 } },
            tools = { { items = { 'hammer', 'toolhammer', 'ironhammer' }, label = 'Hammer' } },
            outputs = { { item = 'lockpickmold', count = 1 } },
            time = 20000,
            maxQuantity = 1,
        },
        cut_cuff_key = {
            label = 'Cut a Handcuff Key',
            description = 'A nail filed down to the shape of a cuff key. Opens most irons a lawman carries.',
            category = 'Outlaw\'s Craft', unlock = 'recipe_page_outlaw',
            ingredients = { { items = { 'iron_nail', 'nails' }, count = 1, label = 'Nail' } },
            tools = { { items = { 'hammer', 'toolhammer', 'ironhammer' }, label = 'Hammer' } },
            outputs = { { item = 'handcuffkey', count = 1 } },
            time = 12000,
            maxQuantity = 2,
        },
        hem_bandana = {
            label = 'Hem a Bandana',
            description = 'A square of cloth hemmed into a bandana. Pull it up over the face when it matters.',
            category = 'Outlaw\'s Craft', unlock = 'recipe_page_outlaw',
            ingredients = { { item = 'cloth', count = 2 }, { item = 'thread', count = 1 } },
            tools = { { items = { 'needle', 'sewing_kit' }, label = 'Needle or sewing kit' } },
            outputs = { { item = 'kit_bandana', count = 1 } },
            time = 9000,
            maxQuantity = 2,
        },
        make_fire_bottle = {
            label = 'Fire Bottle',
            description = 'Lamp oil in a bottle with a rag stuffed in the neck.',
            category = 'Outlaw\'s Craft', unlock = 'recipe_page_outlaw',
            ingredients = { { item = 'empty_bottle', count = 1 }, { item = 'lamp_oil', count = 1 }, { item = 'cloth', count = 1 } },
            outputs = { { item = 'ammomolotov', count = 1 } },
            time = 7000,
            maxQuantity = 3,
        },
        mill_black_powder = {
            label = 'Mill Black Powder',
            description = 'Sulfur and charcoal ground fine in the mortar. Crude, but it burns.',
            category = 'Outlaw\'s Craft', station = 'mortar', unlock = 'recipe_page_outlaw',
            ingredients = { { item = 'sulfur', count = 1 }, { item = 'charcoal', count = 2 } },
            outputs = { { item = 'gunpowder', count = 2 } },
            time = 12000,
            maxQuantity = 5,
        },
        pack_pipe_charge = {
            label = 'Pack a Pipe Charge',
            description = 'Black powder tamped into a copper pipe with a rope fuse. Opens safes the hard way.',
            category = 'Outlaw\'s Craft', unlock = 'recipe_page_outlaw',
            ingredients = { { items = { 'pipecopper', 'copper_pipe' }, count = 1, label = 'Copper pipe' },
                            { item = 'gunpowder', count = 3 }, { item = 'rope', count = 1 } },
            tools = { { items = { 'hammer', 'toolhammer', 'ironhammer' }, label = 'Hammer' } },
            outputs = { { item = 'dynamite', count = 1 } },
            time = 18000,
            maxQuantity = 2,
        },

        -- ---------------- Campfire Cooking (cooking fire: a placed one, a camp cook rig or a campfire) ----------------
        cook_raw_meat     = { label = 'Cook Meat', description = 'A cut of meat cooked through over the coals.', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'raw_meat', count = 1 } }, outputs = { { item = 'cooked_meat', count = 1 } }, time = 6000 },
        cook_small_meat   = { label = 'Cook a Small Cut', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'small_raw_meat', count = 1 } }, outputs = { { item = 'small_cooked_meat', count = 1 } }, time = 5000 },
        cook_large_meat   = { label = 'Cook a Large Cut', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'large_raw_meat', count = 1 } }, outputs = { { item = 'large_cooked_meat', count = 1 } }, time = 8000 },
        cook_bird         = { label = 'Roast Bird', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'bird_meat', count = 1 } }, outputs = { { item = 'cookedbird_meat', count = 1 } }, time = 6000 },
        cook_large_bird   = { label = 'Roast a Large Bird', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'large_bird_meat', count = 1 } }, outputs = { { item = 'cookedlarge_bird_meat', count = 1 } }, time = 8000 },
        cook_game         = { label = 'Cook Game Meat', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { items = { 'game', 'Gamey_Meat' }, count = 1, label = 'Game meat' } }, outputs = { { item = 'consumable_meat_game_cooked', count = 1 } }, time = 6000 },
        cook_venison      = { label = 'Cook Venison', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'venison', count = 1 } }, outputs = { { item = 'meat_venison_cooked', count = 1 } }, time = 7000 },
        cook_big_game     = { label = 'Cook Big Game', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'biggame', count = 1 } }, outputs = { { item = 'meat_big_game_cooked', count = 1 } }, time = 9000 },
        cook_beef         = { label = 'Cook Beef', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'beef', count = 1 } }, outputs = { { item = 'meat_beef_cooked', count = 1 } }, time = 7000 },
        cook_pork         = { label = 'Cook Pork', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'pork', count = 1 } }, outputs = { { item = 'meat_pork_cooked', count = 1 } }, time = 7000 },
        cook_mutton       = { label = 'Cook Mutton', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'Mutton', count = 1 } }, outputs = { { item = 'meat_mutton_cooked', count = 1 } }, time = 7000 },
        cook_herptile     = { label = 'Cook Snake & Lizard', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'herptile', count = 1 } }, outputs = { { item = 'meat_herptile_cooked', count = 1 } }, time = 6000 },
        cook_gator        = { label = 'Cook Alligator', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'aligatormeat', count = 1 } }, outputs = { { item = 'meat_alligator_cooked', count = 1 } }, time = 8000 },
        cook_fish         = { label = 'Cook Fish', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { items = { 'raw_fish', 'fish', 'fishmeat' }, count = 1, label = 'Fish' } }, outputs = { { item = 'cooked_fish', count = 1 } }, time = 5000 },
        cook_flakey_fish  = { label = 'Cook Flaky Fish', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'provision_flakey_fish_meat', count = 1 } }, outputs = { { item = 'cooked_flakey_fish_meat', count = 1 } }, time = 5000 },
        cook_gritty_fish  = { label = 'Cook Gritty Fish', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'provision_gritty_fish_meat', count = 1 } }, outputs = { { item = 'cooked_gritty_fish_meat', count = 1 } }, time = 5000 },
        cook_succulent_fish = { label = 'Cook Succulent Fish', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'provision_succulent_fish_meat', count = 1 } }, outputs = { { item = 'cooked_succulent_fish_meat', count = 1 } }, time = 5000 },
        cook_venison_oregano = { label = 'Venison with Oregano', description = 'Venison rubbed with wild oregano before it goes over the fire.', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'venison', count = 1 }, { items = { 'consumable_herb_oregano', 'herb_oregano' }, count = 1, label = 'Oregano' } },
                              outputs = { { item = 'meat_venison_oregano_cooked', count = 1 } }, time = 8000 },
        cook_venison_thyme = { label = 'Venison with Thyme', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'venison', count = 1 }, { items = { 'consumable_herb_creeping_thyme', 'herb_creeping_thyme' }, count = 1, label = 'Thyme' } },
                              outputs = { { item = 'meat_venison_thyme_cooked', count = 1 } }, time = 8000 },
        cook_pork_mint    = { label = 'Pork with Wild Mint', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'pork', count = 1 }, { items = { 'consumable_herb_wild_mint', 'herb_wild_mint' }, count = 1, label = 'Wild mint' } },
                              outputs = { { item = 'meat_tender_pork_wild_mint_cooked', count = 1 } }, time = 8000 },
        cook_venison_jerky = { label = 'Venison Jerky', description = 'Thin strips salted and dried slow over the smoke. Keeps for the trail.', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'venison', count = 2 }, { item = 'salt', count = 1 } }, outputs = { { item = 'meat_venison_jerky', count = 2 } }, time = 12000, maxQuantity = 5 },
        cook_fried_eggs   = { label = 'Fried Eggs', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { items = { 'eggs', 'egg' }, count = 2, label = 'Eggs' } }, outputs = { { item = 'fried_eggs', count = 1 } }, time = 5000 },
        cook_camp_stew    = { label = 'Camp Stew', description = 'Whatever meat there is, with carrot and potato in the pot.', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { items = { 'raw_meat', 'venison', 'game', 'beef', 'pork' }, count = 1, label = 'Meat' },
                                              { item = 'carrot', count = 1 }, { item = 'potato', count = 1 }, { item = 'water', count = 1 } },
                              outputs = { { item = 'stew', count = 2 } }, time = 12000 },
        cook_coffee       = { label = 'Camp Coffee', description = 'Grounds boiled in the pot until it could float a horseshoe.', category = 'Campfire Cooking', station = 'campfire',
                              ingredients = { { item = 'coffee_beans', count = 1 }, { item = 'water', count = 1 } }, outputs = { { item = 'consumable_coffee', count = 2 } }, time = 6000 },
    },
}
