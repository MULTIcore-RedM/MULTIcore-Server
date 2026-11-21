-- ============================================================
-- MULTIconsumables :: what each item does
-- Every item listed here becomes usable through MULTIinventory, unless another script
-- (an RSG CreateUseableItem, a VORP registerUsableItem or another RegisterUsable) already
-- handles it: then that script keeps the item and nothing here runs for it.
--
--   anim         a key of Config.Anims (config/anims.lua)
--   prop         hand prop for this item (replaces the anim's default; names from redm-info objects.lua)
--   hunger       added to hunger (0-100, 100 = full); negative makes the player hungrier
--   thirst       added to thirst (0-100, 100 = not thirsty)
--   stress       added to stress (0-100); NEGATIVE RELIEVES stress
--   health       outer health points healed (the red bar; negative hurts, never kills)
--   healthCore   added to the health core (0-100)
--   stamina      outer stamina added (the game's stamina points)
--   staminaCore  added to the stamina core (0-100)
--   alcohol      drunk level added (Config.Drunk)
--   sober        drunk level removed (coffee, water ...)
--   substance    addiction key (Config.Addiction.Substances): each use feeds the habit, eases
--                its withdrawal, and its tolerance weakens the good effects above
--   addiction    habit added per use (default: the substance's gainPerUse)
--   cures        { substance = amount } habit removed (cure items)
--   relief       seconds without cravings or withdrawal for every substance in `cures`
--   requires     another item that must be in the satchel and is not used up (e.g. the pipe)
--   returns      item given back after use (a canteen one step emptier, an empty bottle ...)
--   refill       used while standing in a river or lake: the item is swapped for this one instead
--                (no water: the normal use runs, or "find water" when the item has nothing to drink)
-- ============================================================

Config.Consumables = {
    -- food (MULTIcore items.lua)
    bread           = { anim = 'eat',        prop = 'p_bread_14_ab_s_a',  hunger = 20, thirst = -2, stress = -2 },
    bread_sour      = { anim = 'eat',        prop = 'p_bread_14_ab_s_a',  hunger = 30, thirst = -2, stress = -3 },
    canned_apricots = { anim = 'eat_canned', prop = 's_canrigapricots01x', hunger = 20, thirst = 15, stress = -2 },
    cooked_meat     = { anim = 'eat',        prop = 'p_meatchunk_sm02x',  hunger = 35, thirst = -3, stress = -3, healthCore = 5 },
    cooked_fish     = { anim = 'eat',        prop = 'p_meatchunk_sm02x',  hunger = 30, thirst = -3, stress = -3, healthCore = 5 },
    stew            = { anim = 'stew',                                    hunger = 50, thirst = 15, stress = -8, healthCore = 10, staminaCore = 10 },
    sugarcube       = { anim = 'eat',        prop = false,                hunger = 2,  staminaCore = 3 },

    -- drink
    water           = { anim = 'drink',      prop = 'p_bottlebeer01a',    thirst = 30, sober = 3 },
    milk            = { anim = 'drink',      prop = 'p_bottle003x',       thirst = 20, hunger = 5, stress = -2 },
    -- canteens (rsg-canteen items): a drink each, one step emptier; refill in a river or lake
    canteen100      = { anim = 'canteen', thirst = 25, returns = 'canteen75', refill = 'canteen100' },
    canteen75       = { anim = 'canteen', thirst = 25, returns = 'canteen50', refill = 'canteen100' },
    canteen50       = { anim = 'canteen', thirst = 25, returns = 'canteen25', refill = 'canteen100' },
    canteen25       = { anim = 'canteen', thirst = 25, returns = 'canteen0',  refill = 'canteen100' },
    canteen0        = { anim = 'refill', refill = 'canteen100', refillOnly = true },
    coffee          = { anim = 'coffee',                                  thirst = 10, stress = -5, sober = 8, staminaCore = 10, stamina = 20 },

    -- alcohol
    beer            = { anim = 'drink', prop = 'p_bottlebeer01a',    thirst = 10, hunger = 2, stress = -5,  alcohol = 6,  substance = 'alcohol' },
    wine            = { anim = 'drink', prop = 'p_bottlewine01x',    thirst = 5,  stress = -8,  alcohol = 10, substance = 'alcohol' },
    whiskey         = { anim = 'drink', prop = 'p_bottlejd01x',      thirst = -5, stress = -12, alcohol = 18, substance = 'alcohol' },
    rum             = { anim = 'drink', prop = 'p_bottlenavyrum01x', thirst = -5, stress = -12, alcohol = 18, substance = 'alcohol' },
    gin             = { anim = 'drink', prop = 'p_bottleslim01x',    thirst = -5, stress = -10, alcohol = 17, substance = 'alcohol' },
    moonshine       = { anim = 'drink', prop = 'p_jug01x',           thirst = -8, stress = -15, alcohol = 30, healthCore = -5, substance = 'alcohol', addiction = 5 },

    -- tobacco
    cigarettes      = { anim = 'smoke_cigarette', stress = -8,  staminaCore = -2, substance = 'tobacco' },
    cigar           = { anim = 'smoke_cigar',     stress = -12, staminaCore = -3, substance = 'tobacco', addiction = 5 },
    pipe_tobacco    = { anim = 'smoke_pipe',      stress = -10, staminaCore = -2, substance = 'tobacco', requires = 'pipe' },
    chewing_tobacco = { anim = 'chew',            stress = -6,  substance = 'tobacco' },

    -- medicine (laudanum is opium in alcohol, so it is a little intoxicating too)
    laudanum        = { anim = 'drink', prop = 'p_bottlemedicine01x', stress = -20, health = 40, healthCore = 15, alcohol = 4, substance = 'laudanum' },
    tonic_healing   = { anim = 'drink', prop = 'p_bottlemedicine02x', health = 50, healthCore = 25 },
    tonic_stamina   = { anim = 'drink', prop = 'p_bottlemedicine02x', stamina = 100, staminaCore = 40 },
    tonic_energy    = { anim = 'drink', prop = 'p_bottlemedicine02x', staminaCore = 25, healthCore = 10, stress = -5 },
    tonic_antidote  = { anim = 'drink', prop = 'p_bottlemedicine03x', health = 25, healthCore = 15 },
    -- cure: eases the habit (set more cure items the same way)
    tonic_temperance = { anim = 'drink', prop = 'p_bottlemedicine03x', stress = -5, sober = 15, cures = { alcohol = 25, laudanum = 20 }, relief = 1800 },
}

-- food, drink and medicine from the picture library (config/consumables_library.lua),
-- whichever of the two files loads first; a line set above always wins
for name, def in pairs(Config.LibraryConsumables or {}) do
    if Config.Consumables[name] == nil then Config.Consumables[name] = def end
end
