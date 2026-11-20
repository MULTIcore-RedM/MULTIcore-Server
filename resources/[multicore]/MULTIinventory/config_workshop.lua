-- ============================================================
-- MULTIinventory :: workshop (crafting journal, grinding wheel, spinning wheel, mortar)
--
--   * Crafting Journal  - the hand-craft recipes (config_handcraft.lua) are read and made
--                          from a book item instead of the inventory's Craft tab.
--   * Stations          - wheels / mortars a player buys, places anywhere and uses. They
--                          crumble away after `lifetimeHours` (then buy a new one).
--   * Grinding wheel     - sharpens a worn tool back to full durability.
--   * Spinning wheel     - opens the journal on "Spinning & Sewing"; recipes with
--                          station = 'spinning_wheel' need one nearby.
--   * Mortar & pestle    - opens the journal on "Apothecary"; recipes with
--                          station = 'mortar' need one nearby (or a mortarpestle carried).
--   * Recipe books       - recipes with unlock = '<item>' stay locked until that item is read.
-- ============================================================

Config = Config or {}

Config.CraftBook = {
    -- 'book' = the Crafting Journal item opens a book (the inventory's Craft tab is hidden)
    -- 'tab'  = the old Craft tab inside the inventory (no book needed; station recipes still need their station)
    mode = 'book',
    item = 'crafting_journal',
    title = 'Crafting Journal',
    -- Book mode: recipes WITHOUT a station need the journal carried. Station recipes only need the station.
    requireBook = true,
    reopenAfterCraft = true,   -- after a craft started from the book, open the book again on the same chapter
    -- Every character gets one journal, once (existing characters too, on their next login). Lost it? Buy one.
    starterJournal = true,

    -- Chapters in book order. A recipe goes into the chapter whose `categories` lists its category
    -- (config_handcraft.lua `category`); anything else ends up in "Other".
    chapters = {
        { key = 'materials', label = 'Materials',          categories = { 'Materials' },          blurb = 'Twine, rope and the odd useful thing made with bare hands.' },
        { key = 'spinning',  label = 'Spinning & Sewing',  categories = { 'Spinning & Sewing' },  blurb = 'Wool and fibre spun at the wheel, then needle and thread.' },
        { key = 'remedies',  label = 'Remedies',           categories = { 'Remedies' },           blurb = 'Clean cloth and bandages for the trail.' },
        { key = 'apothecary', label = 'Apothecary',        categories = { 'Apothecary' },         blurb = 'Herbs ground in the mortar into salves, tonics and teas.' },
        { key = 'cooking',   label = 'Campfire Cooking',   categories = { 'Campfire Cooking' },   blurb = 'Meat, fish and a pot of coffee over the fire.' },
        { key = 'tobacco',   label = 'Tobacco',            categories = { 'Tobacco' },            blurb = 'Papers, leaf and a steady hand.' },
        { key = 'provisions', label = 'Provisions',        categories = { 'Provisions' },         blurb = 'Bait and small comforts.' },
        { key = 'spirit',    label = 'Spirit Blends',      categories = { 'Spirit Blends' },      blurb = 'Ceremonial blends for the peace pipe.' },
        { key = 'outlaw',    label = 'Outlaw\'s Craft',    categories = { 'Outlaw\'s Craft' },    blurb = 'Lockpicks, keys and worse. Learned from stolen notes, or from someone who knows the trade.' },
    },

    -- Recipe books: reading the item learns every recipe whose `unlock` names it (saved per character).
    recipeBooks = {
        consumeOnRead = true,   -- the pages are used up once learned
        items = {
            recipe_knitting   = { label = 'Knitting Patterns' },
            recipe_tailoring  = { label = 'A Tailor\'s Notes' },
            recipe_apothecary = { label = 'Apothecary\'s Formulary' },
        },
    },

    -- Recipe pages: ONE recipe on a loose sheet. Reading it learns that recipe (the page is used up).
    --   * A page with metadata.recipe = '<recipe id>' teaches that recipe (handwritten copies, gifts, exports).
    --   * A page WITHOUT metadata teaches a random recipe from its pool that the reader does not know yet -
    --     put these items in robbery / NPC loot tables, no metadata needed:
    --         recipe_page       (common pool)        recipe_page_rare   (rare pool)
    --         recipe_page_outlaw  (Outlaw's Notes: lockpicks, cuff keys, fire bottles, black powder)
    --     A reader who already knows the whole pool keeps the page (sell it or give it away).
    --   * Recipes with unlock = 'recipe_page' can ONLY be learned from a page (loot-only recipes).
    --   * Anyone who knows an unlockable recipe can write a copy from its page in the journal
    --     (costs `copy.ingredients`), then give or sell it.
    recipePapers = {
        writtenItem = 'recipe_page',   -- the item a written copy becomes
        pools = {
            -- weight = how likely; recipes the reader already knows are skipped
            recipe_page = {
                { recipe = 'craft_field_dressing', weight = 10 }, { recipe = 'craft_honey_bandage', weight = 10 },
                { recipe = 'mix_horse_ointment', weight = 8 },   { recipe = 'sew_feedbag', weight = 8 },
                { recipe = 'brew_snake_oil', weight = 6 },       { recipe = 'sew_saddle_blanket', weight = 6 },
                { recipe = 'knit_wool_scarf', weight = 5 },      { recipe = 'sew_fine_bandages', weight = 5 },
                { recipe = 'stitch_leather_belt', weight = 4 },  { recipe = 'mix_smelling_salts', weight = 3 },
            },
            recipe_page_rare = {
                { recipe = 'sew_fur_blanket', weight = 10 },     { recipe = 'stitch_leather_satchel', weight = 8 },
                { recipe = 'brew_ginseng_elixir', weight = 8 },  { recipe = 'knit_wool_blanket', weight = 6 },
                { recipe = 'make_sewing_kit', weight = 6 },      { recipe = 'brew_herbal_medicine', weight = 5 },
                { recipe = 'brew_laudanum', weight = 3 },
            },
            -- Outlaw's Notes: robbery loot. Rory Dolan's "Tricks of the Trade" missions
            -- (RINGOnpcmissions) teach the same recipes one by one.
            recipe_page_outlaw = {
                { recipe = 'bend_lockpick', weight = 10 },      { recipe = 'hem_bandana', weight = 8 },
                { recipe = 'cut_cuff_key', weight = 6 },        { recipe = 'make_fire_bottle', weight = 6 },
                { recipe = 'cast_lockpicks', weight = 4 },      { recipe = 'mill_black_powder', weight = 3 },
                { recipe = 'cast_lockpick_mold', weight = 2 },  { recipe = 'pack_pipe_charge', weight = 1 },
            },
        },
        copy = {
            enabled = true,
            time = 8000,
            ingredients = {
                { items = { 'paper', 'blank_map_paper', 'document_paper' }, count = 1, label = 'Paper' },
                { items = { 'ink', 'ink_bottle' }, count = 1, label = 'Ink' },
            },
            tools = {},
        },
    },
}

Config.Stations = {
    enabled = true,
    lifetimeHours = 48,          -- a placed station is removed this long after it was FIRST put down (picking it up does not reset it)
    maxPerCharacter = 2,         -- per station type
    useItemPlacer = true,        -- use RINGOitemplacer's placement preview when it is running (else the built-in one)
    placeDistance = 5.0,         -- metres from the player a station may be put down
    interactDistance = 2.5,      -- target distance
    recipeRadius = 3.5,          -- metres: how close a station has to be for its recipes
    streamDistance = 120.0,      -- client: spawn placed stations within this range
    sessionMinutes = 10,         -- a station opened by target counts as "nearby" this long (while you stay close)
    -- Wheels / mortars already in the world (map props, housing furniture) can be used too. The server
    -- then trusts the prop position the client reports (it still checks the player is standing there).
    worldProps = true,
    allowPickup = true,          -- the owner can pick a placed station up again (keeps its remaining life)

    types = {
        grinding_wheel = {
            label = 'Grinding Wheel',
            item = 'grinding_wheel',
            model = 'p_grindingwheel01x',
            worldModels = { 'p_grindingwheel01x', 'p_cs_grindingwheelx' },
            icon = 'fa-solid fa-gear',
            action = 'sharpen',
            targetLabel = 'Sharpen a tool',
        },
        spinning_wheel = {
            label = 'Spinning Wheel',
            item = 'spinning_wheel',
            model = 'p_spinningwheel02x',
            worldModels = { 'p_spinningwheel02x', 'p_spinningwheel01x' },
            icon = 'fa-solid fa-book-open',
            action = 'book', chapter = 'spinning',
            targetLabel = 'Spin & sew',
        },
        mortar = {
            label = 'Mortar & Pestle',
            item = 'herbalist_mortar',
            model = 'p_mortarpestle02x',
            worldModels = { 'p_mortarpestle02x', 'p_mortarpestle02bx', 'p_mortarpestle01x' },
            carryItems = { 'mortarpestle' },   -- carrying a hand mortar also counts as being at one
            icon = 'fa-solid fa-mortar-pestle',
            action = 'book', chapter = 'apothecary',
            targetLabel = 'Grind herbs',
        },
        -- cooking fire: the camp cook rig with its own small fire and a cast-iron pot hanging on it.
        -- attach = extra props spawned with the station (offset in its own space, metres; no collision).
        campfire = {
            label = 'Cooking Fire',
            item = 'cooking_fire',
            model = 'p_campfirecook01x',
            attach = {
                { model = 'p_campfirefresh01x',  offset = { x = 0.15, y = -0.15, z = 0.0 } },    -- the fire
                { model = 'p_cast_iron_pot_001', offset = { x = 0.15, y = -0.15, z = 0.47 } },  -- the pot on the rig
            },
            -- camp cook rigs and campfires already in the world count too
            worldModels = { 'p_campfirecook01x', 'p_campfire02x', 'p_campfirecombined01x', 'p_campfire01x',
                            'p_campfire03x', 'p_campfire04x', 'p_campfire05x' },
            icon = 'fa-solid fa-fire',
            action = 'book', chapter = 'cooking',
            targetLabel = 'Cook',
        },
        -- job stations (recipes in config_handcraft_jobs.lua; only the matching trades can use them)
        anvil = {
            label = 'Anvil',
            item = 'anvil',
            model = 'p_anvil01x',
            worldModels = { 'p_anvil01x' },          -- smithy anvils and other placed anvils count too
            icon = 'fa-solid fa-hammer',
            action = 'book',
            targetLabel = 'Work at the anvil',
        },
        workbench = {
            label = 'Workbench',
            item = 'camp_workbench',
            model = 'p_workbench01x',
            worldModels = { 'p_workbench01x', 'p_workbench02x' },
            icon = 'fa-solid fa-screwdriver-wrench',
            action = 'book',
            targetLabel = 'Work at the bench',
        },
        hide_frame = {
            label = 'Hide Frame',
            item = 'hide_frame',
            model = 'p_hideframe01x',
            worldModels = { 'p_hideframe01x', 'p_hideframe02x' },
            icon = 'fa-solid fa-paw',
            action = 'book',
            targetLabel = 'Work the hides',
        },
    },
}

Config.Sharpening = {
    enabled = true,
    station = 'grinding_wheel',
    maxDurability = 100,
    time = 9000,                 -- ms at the wheel
    -- Each sharpen uses this (first one carried). cost = false for free sharpening.
    cost = { items = { 'oil', 'lamp_oil' }, count = 1, label = 'Oil' },
    -- Verified in game: RINGObutcherjob plays this knife-sharpening clip. A scenario can be used instead:
    -- anim = { scenario = 'WORLD_HUMAN_...' }
    anim = { dict = 'amb_camp@world_camp_pearson_sharpen_knife@male_a@idle_a', clip = 'idle_a', flag = 31 },
    log = true,

    -- Tools the wheel takes. Key = item name.
    --   brokenLabel   metadata.label another script sets while the tool is broken (removed again)
    --   description   metadata.description written after sharpening (nil = leave the description alone)
    -- Durability is metadata.durability 0-100 (RINGOminingcorp, MULTIinventory WearItem, ...).
    tools = {
        pickaxe            = { brokenLabel = 'Pickaxe (broken)', description = 'Durability 100% - Sharp' },  -- RINGOminingcorp
        axe                = {},
        lumberaxe          = {},
        hatchet            = {},
        handsaw            = {},
        woodsaw            = {},
        shovel             = {},
        prospecting_shovel = {},
        butcher_cleaver    = {},
        kit_hoof_knife     = {},
        bee_uncapping_knife = {},
        herb_trowel        = {},
        knife_blade        = {},
    },
}
