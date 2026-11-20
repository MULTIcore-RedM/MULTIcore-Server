-- ============================================================
-- MULTIinventory :: weapons & ammo
-- Weapon/ammo game data: shared/weapons.lua. Natives: client/weapons.lua (WeaponNatives).
-- ============================================================

Config.Weapons = {
    -- Weapons are unique slot items (multiinv_weapons) with a serial number.
    serialFormat = '%s-%06d',      -- prefix, number (number = weapon id) -> RNG-000123
    serialPrefix = 'RNG',
    customLabelMax = 50,           -- column sizes of multiinv_weapons
    customDescMax = 255,
    allowRename = false,           -- players may rename their own weapons from the inventory

    -- Gunbelt: spare ammo per character and ammo type (multiinv_ammo).
    -- Rounds in a weapon's magazine travel with the weapon (multiinv_weapons.ammo).
    -- Equip puts the weapon on the ped with its loaded rounds; the game reloads from the
    -- gunbelt. The client reports ammo + condition every reportSeconds and on holster;
    -- the server never accepts more ammo than it handed out (conservation per ammo type).
    reportSeconds = 5,
    ammoMax = {},                  -- per-type gunbelt maximum overrides, e.g. { AMMO_REVOLVER = 200 }

    -- Ammo items: using one adds `amount` rounds of `type` to the gunbelt (the item is used up).
    -- wholeStack = true: the item IS one round - using it moves the whole stack onto the gunbelt
    -- (as much as fits). Another script may register its own use for any of these names; the
    -- gunbelt use then only runs when nothing else handles the item.
    registerAmmoUsables = true,
    ammoItems = {
        -- MULTIcore's item list (MULTIcore shared/items.lua): ammo boxes and arrow bundles
        ammo_box_revolver                    = { type = 'AMMO_REVOLVER', amount = 12 },
        ammo_box_revolver_express            = { type = 'AMMO_REVOLVER_EXPRESS', amount = 12 },
        ammo_box_revolver_explosive          = { type = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', amount = 10 },
        ammo_box_revolver_velocity           = { type = 'AMMO_REVOLVER_HIGH_VELOCITY', amount = 12 },
        ammo_box_revolver_splitpoint         = { type = 'AMMO_REVOLVER_SPLIT_POINT', amount = 12 },
        ammo_box_pistol                      = { type = 'AMMO_PISTOL', amount = 12 },
        ammo_box_pistol_express              = { type = 'AMMO_PISTOL_EXPRESS', amount = 12 },
        ammo_box_pistol_explosive            = { type = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', amount = 10 },
        ammo_box_pistol_velocity             = { type = 'AMMO_PISTOL_HIGH_VELOCITY', amount = 12 },
        ammo_box_pistol_splitpoint           = { type = 'AMMO_PISTOL_SPLIT_POINT', amount = 12 },
        ammo_box_repeater                    = { type = 'AMMO_REPEATER', amount = 12 },
        ammo_box_repeater_express            = { type = 'AMMO_REPEATER_EXPRESS', amount = 12 },
        ammo_box_repeater_explosive          = { type = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', amount = 10 },
        ammo_box_repeater_velocity           = { type = 'AMMO_REPEATER_HIGH_VELOCITY', amount = 12 },
        ammo_box_repeater_splitpoint         = { type = 'AMMO_REPEATER_SPLIT_POINT', amount = 12 },
        ammo_box_rifle                       = { type = 'AMMO_RIFLE', amount = 12 },
        ammo_box_rifle_express               = { type = 'AMMO_RIFLE_EXPRESS', amount = 12 },
        ammo_box_rifle_explosive             = { type = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', amount = 10 },
        ammo_box_rifle_velocity              = { type = 'AMMO_RIFLE_HIGH_VELOCITY', amount = 12 },
        ammo_box_rifle_splitpoint            = { type = 'AMMO_RIFLE_SPLIT_POINT', amount = 12 },
        ammo_box_rifle_elephant              = { type = 'AMMO_RIFLE_ELEPHANT', amount = 10 },
        ammo_box_shotgun                     = { type = 'AMMO_SHOTGUN', amount = 12 },
        ammo_box_shotgun_buckshot_incendiary = { type = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', amount = 7 },
        ammo_box_shotgun_slug                = { type = 'AMMO_SHOTGUN_SLUG', amount = 12 },
        ammo_box_shotgun_slug_explosive      = { type = 'AMMO_SHOTGUN_EXPRESS_EXPLOSIVE', amount = 10 },
        ammo_box_varmint                     = { type = 'AMMO_22', amount = 12 },
        ammo_box_varmint_tranquilizer        = { type = 'AMMO_22_TRANQUILIZER', amount = 12 },
        ammo_arrow                           = { type = 'AMMO_ARROW', amount = 10 },
        ammo_arrow_small                     = { type = 'AMMO_ARROW_SMALL_GAME', amount = 10 },
        ammo_arrow_fire                      = { type = 'AMMO_ARROW_FIRE', amount = 3 },
        ammo_arrow_poison                    = { type = 'AMMO_ARROW_POISON', amount = 2 },
        ammo_arrow_dynamite                  = { type = 'AMMO_ARROW_DYNAMITE', amount = 1 },

        -- loose rounds (one item = one round; crafting recipes and older satchels hand these out).
        -- MULTIinventory adds these item definitions itself when no other resource has them.
        ammo_revolver                        = { type = 'AMMO_REVOLVER', amount = 1, wholeStack = true, label = 'Revolver Cartridge' },
        ammo_revolver_express                = { type = 'AMMO_REVOLVER_EXPRESS', amount = 1, wholeStack = true, label = 'Revolver Cartridge (Express)' },
        ammo_revolver_express_explosive      = { type = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', amount = 1, wholeStack = true, label = 'Revolver Cartridge (Explosive)' },
        ammo_revolver_high_velocity          = { type = 'AMMO_REVOLVER_HIGH_VELOCITY', amount = 1, wholeStack = true, label = 'Revolver Cartridge (High Velocity)' },
        ammo_revolver_split_point            = { type = 'AMMO_REVOLVER_SPLIT_POINT', amount = 1, wholeStack = true, label = 'Revolver Cartridge (Split Point)' },
        ammo_pistol                          = { type = 'AMMO_PISTOL', amount = 1, wholeStack = true, label = 'Pistol Cartridge' },
        ammo_pistol_express                  = { type = 'AMMO_PISTOL_EXPRESS', amount = 1, wholeStack = true, label = 'Pistol Cartridge (Express)' },
        ammo_pistol_express_explosive        = { type = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', amount = 1, wholeStack = true, label = 'Pistol Cartridge (Explosive)' },
        ammo_pistol_high_velocity            = { type = 'AMMO_PISTOL_HIGH_VELOCITY', amount = 1, wholeStack = true, label = 'Pistol Cartridge (High Velocity)' },
        ammo_pistol_split_point              = { type = 'AMMO_PISTOL_SPLIT_POINT', amount = 1, wholeStack = true, label = 'Pistol Cartridge (Split Point)' },
        ammo_repeater                        = { type = 'AMMO_REPEATER', amount = 1, wholeStack = true, label = 'Repeater Cartridge' },
        ammo_repeater_express                = { type = 'AMMO_REPEATER_EXPRESS', amount = 1, wholeStack = true, label = 'Repeater Cartridge (Express)' },
        ammo_repeater_express_explosive      = { type = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', amount = 1, wholeStack = true, label = 'Repeater Cartridge (Explosive)' },
        ammo_repeater_high_velocity          = { type = 'AMMO_REPEATER_HIGH_VELOCITY', amount = 1, wholeStack = true, label = 'Repeater Cartridge (High Velocity)' },
        ammo_repeater_split_point            = { type = 'AMMO_REPEATER_SPLIT_POINT', amount = 1, wholeStack = true, label = 'Repeater Cartridge (Split Point)' },
        ammo_rifle                           = { type = 'AMMO_RIFLE', amount = 1, wholeStack = true, label = 'Rifle Cartridge' },
        ammo_rifle_express                   = { type = 'AMMO_RIFLE_EXPRESS', amount = 1, wholeStack = true, label = 'Rifle Cartridge (Express)' },
        ammo_rifle_express_explosive         = { type = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', amount = 1, wholeStack = true, label = 'Rifle Cartridge (Explosive)' },
        ammo_rifle_high_velocity             = { type = 'AMMO_RIFLE_HIGH_VELOCITY', amount = 1, wholeStack = true, label = 'Rifle Cartridge (High Velocity)' },
        ammo_rifle_split_point               = { type = 'AMMO_RIFLE_SPLIT_POINT', amount = 1, wholeStack = true, label = 'Rifle Cartridge (Split Point)' },
        ammo_rifle_elephant                  = { type = 'AMMO_RIFLE_ELEPHANT', amount = 1, wholeStack = true, label = 'Elephant Rifle Cartridge' },
        ammo_22                              = { type = 'AMMO_22', amount = 1, wholeStack = true, label = 'Varmint Cartridge' },
        ammo_22_tranquilizer                 = { type = 'AMMO_22_TRANQUILIZER', amount = 1, wholeStack = true, label = 'Tranquilizer Cartridge' },
        ammo_shotgun                         = { type = 'AMMO_SHOTGUN', amount = 1, wholeStack = true, label = 'Shotgun Shell' },
        ammo_shotgun_buckshot_incendiary     = { type = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', amount = 1, wholeStack = true, label = 'Incendiary Buckshot Shell' },
        ammo_shotgun_slug                    = { type = 'AMMO_SHOTGUN_SLUG', amount = 1, wholeStack = true, label = 'Shotgun Slug' },
        ammo_shotgun_slug_explosive          = { type = 'AMMO_SHOTGUN_EXPRESS_EXPLOSIVE', amount = 1, wholeStack = true, label = 'Explosive Slug' },
        ammo_arrow_single                    = { type = 'AMMO_ARROW', amount = 1, wholeStack = true, label = 'Arrow' },
        ammo_arrow_small_single              = { type = 'AMMO_ARROW_SMALL_GAME', amount = 1, wholeStack = true, label = 'Small Game Arrow' },
        ammo_arrow_fire_single               = { type = 'AMMO_ARROW_FIRE', amount = 1, wholeStack = true, label = 'Fire Arrow' },
        ammo_arrow_poison_single             = { type = 'AMMO_ARROW_POISON', amount = 1, wholeStack = true, label = 'Poison Arrow' },
        ammo_arrow_dynamite_single           = { type = 'AMMO_ARROW_DYNAMITE', amount = 1, wholeStack = true, label = 'Dynamite Arrow' },

        -- short names some gunsmith scripts use (one box = 10 rounds)
        ammorevolvernormal     = { type = 'AMMO_REVOLVER', amount = 10 },
        ammorevolverexpress    = { type = 'AMMO_REVOLVER_EXPRESS', amount = 10 },
        ammorevolverexplosive  = { type = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', amount = 10 },
        ammorevolvervelocity   = { type = 'AMMO_REVOLVER_HIGH_VELOCITY', amount = 10 },
        ammorevolversplitpoint = { type = 'AMMO_REVOLVER_SPLIT_POINT', amount = 10 },
        ammopistolnormal       = { type = 'AMMO_PISTOL', amount = 10 },
        ammopistolexpress      = { type = 'AMMO_PISTOL_EXPRESS', amount = 10 },
        ammopistolexplosive    = { type = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', amount = 10 },
        ammopistolvelocity     = { type = 'AMMO_PISTOL_HIGH_VELOCITY', amount = 10 },
        ammopistolsplitpoint   = { type = 'AMMO_PISTOL_SPLIT_POINT', amount = 10 },
        ammorepeaternormal     = { type = 'AMMO_REPEATER', amount = 10 },
        ammorepeaterexpress    = { type = 'AMMO_REPEATER_EXPRESS', amount = 10 },
        ammorepeaterexplosive  = { type = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', amount = 10 },
        ammorepeatervelocity   = { type = 'AMMO_REPEATER_HIGH_VELOCITY', amount = 10 },
        ammorepeatersplitpoint = { type = 'AMMO_REPEATER_SPLIT_POINT', amount = 10 },
        ammoriflenormal        = { type = 'AMMO_RIFLE', amount = 10 },
        ammorifleexpress       = { type = 'AMMO_RIFLE_EXPRESS', amount = 10 },
        ammorifleexplosive     = { type = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', amount = 10 },
        ammoriflevelocity      = { type = 'AMMO_RIFLE_HIGH_VELOCITY', amount = 10 },
        ammoriflesplitpoint    = { type = 'AMMO_RIFLE_SPLIT_POINT', amount = 10 },
        ammorifleelephant      = { type = 'AMMO_RIFLE_ELEPHANT', amount = 10 },
        ammovarmint            = { type = 'AMMO_22', amount = 10 },
        ammovarminttranq       = { type = 'AMMO_22_TRANQUILIZER', amount = 10 },
        ammoshotgunnormal      = { type = 'AMMO_SHOTGUN', amount = 10 },
        ammoshotgunslug        = { type = 'AMMO_SHOTGUN_SLUG', amount = 10 },
        ammoshotgunincendiary  = { type = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', amount = 10 },
        ammoshotgunexplosive   = { type = 'AMMO_SHOTGUN_EXPRESS_EXPLOSIVE', amount = 10 },
        ammoarrownormal        = { type = 'AMMO_ARROW', amount = 10 },
        ammoarrowimproved      = { type = 'AMMO_ARROW_IMPROVED', amount = 10 },
        ammoarrowfire          = { type = 'AMMO_ARROW_FIRE', amount = 5 },
        ammoarrowpoison        = { type = 'AMMO_ARROW_POISON', amount = 5 },
        ammoarrowdynamite      = { type = 'AMMO_ARROW_DYNAMITE', amount = 5 },
        ammoarrowsmallgame     = { type = 'AMMO_ARROW_SMALL_GAME', amount = 10 },
    },

    -- Throwables (dynamite, fire bottles, tomahawks, throwing knives, bolas, poison bottles) work like
    -- RDR2: ONE inventory stack per kind, its number = how many you can throw. Equip it (inventory or
    -- hotbar) and the ped gets that many of the right ammo type; every throw takes one off the stack
    -- (the server checks the count, it can never go up or below 0); the last throw removes the stack.
    -- A new throwable of the same kind joins the stack you already carry (up to stackMax, then a new
    -- stack). Rows saved before this existed with no count are read as defaultCount.
    thrown = {
        -- count a throwable gets when it is created without ammo (vorp createWeapon / shops / admin)
        defaultCountAll = 1,
        defaultCount = { WEAPON_THROWN_THROWING_KNIVES = 0 },   -- knives come as belt ammo (ammoknives)
        stackMax = {},             -- per weapon, e.g. { WEAPON_THROWN_DYNAMITE = 10 } (default: ammo max)
    },
    -- Throwable items: using one adds `amount` of `type` to the matching throwable stack (creates it if
    -- needed). Skipped for items another resource already made usable (RINGOgunsmith registers the same
    -- names; its throwables land on the same stack through createWeapon).
    thrownItems = {
        ammodynamite       = { weapon = 'WEAPON_THROWN_DYNAMITE', type = 'AMMO_DYNAMITE', amount = 1 },
        ammovoldynamite    = { weapon = 'WEAPON_THROWN_DYNAMITE', type = 'AMMO_DYNAMITE_VOLATILE', amount = 1 },
        ammomolotov        = { weapon = 'WEAPON_THROWN_MOLOTOV', type = 'AMMO_MOLOTOV', amount = 1 },
        ammovolmolotov     = { weapon = 'WEAPON_THROWN_MOLOTOV', type = 'AMMO_MOLOTOV_VOLATILE', amount = 1 },
        ammotomahawk       = { weapon = 'WEAPON_THROWN_TOMAHAWK', type = 'AMMO_TOMAHAWK', amount = 1 },
        ammoknives         = { weapon = 'WEAPON_THROWN_THROWING_KNIVES', type = 'AMMO_THROWING_KNIVES', amount = 5 },
        ammobolla          = { weapon = 'WEAPON_THROWN_BOLAS', type = 'AMMO_BOLAS', amount = 1 },
        ammobolahawk       = { weapon = 'WEAPON_THROWN_BOLAS_HAWKMOTH', type = 'AMMO_BOLAS_HAWKMOTH', amount = 1 },
        ammobolaironspiked = { weapon = 'WEAPON_THROWN_BOLAS_IRONSPIKED', type = 'AMMO_BOLAS_IRONSPIKED', amount = 1 },
        ammobolainterwired = { weapon = 'WEAPON_THROWN_BOLAS_INTERTWINED', type = 'AMMO_BOLAS_INTERTWINED', amount = 1 },
        ammopoisonbottle   = { weapon = 'WEAPON_THROWN_POISONBOTTLE', type = 'AMMO_POISONBOTTLE', amount = 1 },
    },

    -- Condition (dirt, soot, degradation, damage; 0..1 like the game natives) is read back
    -- from the weapon object and saved. Reports can only make a weapon dirtier/more worn;
    -- only cleaning (server side) lowers the values.
    saveCondition = true,
    -- Cleaning items: use one (or the inventory's "Clean" button) on a weapon.
    -- Values are the new level (dirt/soot) or how much is taken off (degradation/damage).
    cleaning = {
        registerUsables = true,    -- skipped for items another resource already made usable
        items = {
            gun_oil           = { dirt = 0.0, soot = 0.0, degradationOff = 0.5, damageOff = 0.0 },
            weapon_repair_kit = { dirt = 0.0, soot = 0.0, degradationOff = 1.0, damageOff = 1.0 },
        },
        animMs = 4000,             -- client plays the cleaning animation this long (0 = none)
        -- RDR2's own gun-cleaning interaction (an equipped weapon is drawn and wiped with a rag):
        -- short-arm version for pistols / revolvers, long-arm for rifles / shotguns / repeaters.
        -- Set animDict + animName instead to play a plain animation.
        nativeAnim = true,
        clothModel = 's_balledragcloth01x',
        shortArmState = 'SHORTARM_CLEAN_ENTER',
        longArmState  = 'LONGARM_CLEAN_ENTER',
    },

    -- Max weapons a character may carry (counted weapons in the player grid).
    maxCarried = 6,
    jobOverrides = {},             -- { sheriff = 10, gunsmith = 12 }
    notCountedGroups = { lasso = true, kit = true },
    notCountedNames = {},          -- { WEAPON_MELEE_KNIFE = true }

    -- Equip slots. A slot holds one weapon; equipping into a full slot holsters the old one.
    -- attach = eWeaponAttachPoint passed to GiveWeaponToPed (holster point while not drawn).
    -- eWeaponAttachPoint: 0 HAND_PRIMARY, 1 HAND_SECONDARY, 2 PISTOL_R, 3 PISTOL_L, 4 KNIFE, 5 LASSO,
    -- 6 THROWER, 7 BOW, 8 BOW_ALTERNATE, 9 RIFLE, 10 RIFLE_ALTERNATE, 11 LANTERN, 12 TEMP_LANTERN, 13 MELEE.
    -- Dual wield: a second sidearm (revolver/pistol) goes to the left hip (off-hand holster).
    -- Drawing a sidearm while both hips hold one draws BOTH (right hand + left hand).
    --   enabled     = false: one sidearm at a time (the right hip only).
    --   requireItem = nil | 'item_name': the off-hand holster needs this item in the player's
    --                 grid or worn in the equipment slots (e.g. a gunbelt / off-hand holster item).
    -- (A plain `dualWield = true/false` from older configs is still understood.)
    dualWield = { enabled = true, requireItem = nil },
    -- Sidearms (right/left hip) go through the game's own inventory (off-hand holster upgrade +
    -- weapon GUIDs bound to hand 0/1) - this is what makes the second gun drawable. While a gun is on
    -- the left hip the character gets the game's off-hand holster; it is taken off when the left hip
    -- empties (so requireItem above also gates the holster). false = old GiveWeaponToPed-only path.
    nativeSidearms = true,
    -- Off-hand (left hip) holster look. Default style / tint for every character; a character's own
    -- choice is set through exports.MULTIinventory:SetOffhandHolsterStyle(style, tint, always)
    -- (RINGOweaponpositions /weaponpos "Holster rig" saves it per character). The male / female item
    -- (CLOTHING_ITEM_M_ / _F_OFFHAND_<style>_TINT_<tint>) is chosen from the ped sex automatically.
    --   style / tint  : 0..10, 14, 15 with tint 1..4; 302 has tint 1 only.
    --   always        : true = wear the off-hand holster even with the left hip empty (two-gun rig look).
    --   allowAlways   : false = ignore every character's "always" choice (holster only with a left gun).
    -- Note: "always" is cosmetic and is NOT gated by dualWield.requireItem.
    -- stripEmpty    : true = with no gun on the left hip, any off-hand leather on the character is taken off
    --                 (also leather from the character creator / saved outfits).
    --   leatherItem   : the off-hand holster LEATHER only shows while the player owns this item (grid or
    --                 worn); without it a left-hip gun still works, just without the leather. nil = always shown.
    offhandHolster = { style = 0, tint = 4, always = false, allowAlways = false, stripEmpty = true, leatherItem = 'offhand_holster' },
    slots = {
        right    = { attach = 2,  label = 'Right hip' },   -- PISTOL_R
        left     = { attach = 3,  label = 'Left hip' },    -- PISTOL_L (offhand)
        back     = { attach = 9,  label = 'Back' },        -- RIFLE
        shoulder = { attach = 10, label = 'Shoulder' },    -- RIFLE_ALTERNATE
        knife    = { attach = 4,  label = 'Knife' },
        lasso    = { attach = 5,  label = 'Lasso' },
        thrown   = { attach = 6,  label = 'Throwable' },
        bow      = { attach = 7,  label = 'Bow' },
        melee    = { attach = 13, label = 'Melee' },
        other    = { attach = 0,  label = 'Hand' },
        -- third revolver (extraSidearm below): NOT on the ped - the game has two sidearm slots only.
        -- Shown on the body by RINGOweaponpositions (state bag 'rinvx'), drawn by swapping it with the right hip.
        extra    = { attach = -1, label = 'Extra holster', virtual = true },
    },
    -- One extra (third) sidearm: it goes to the virtual 'extra' slot once both hips are full. It is not given to
    -- the game (two sidearm slots only); RINGOweaponpositions shows it on the body when it runs. HOLD holdKey
    -- (default T - X is hands up) for holdMs, or use the command, to draw it: it swaps with the right-hip gun, which then goes
    -- to the extra holster. enabled = false: two sidearms as before.
    extraSidearm = { enabled = true, holdKey = 0x9720FCEE, holdMs = 450, command = 'drawextra', cooldownMs = 1500 },
    -- Long arms: nil / { 'back', 'shoulder' } = two (default); { 'back' } = one long arm only.
    longArmSlots = nil,
    kitAttach = 0,                 -- 'kit:<name>' slots (binoculars, lantern, camera...)
    reequipOnSpawn = true,         -- weapons equipped at logout/death are given back on spawn

    extraDefs = {},                -- add-on weapons: { WEAPON_X = { label, group, clip, weight, ammoTypes } }

    adminCommands = {
        give    = 'invgiveweapon',     -- /invgiveweapon <target> <WEAPON_NAME> [serial]
        restore = 'invrestoreweapon',  -- /invrestoreweapon <logId> [target]
        ammo    = 'invammo',           -- /invammo <target> <AMMO_TYPE> <count>  (sets the gunbelt)
    },
}

-- Weapon audit rows written to multiinv_log (core Config.Log.actions gate).
Config.Log = Config.Log or {}
Config.Log.actions = Config.Log.actions or {}
for _, a in ipairs({ 'weapon_create', 'weapon_delete', 'weapon_detach', 'weapon_clean', 'ammo_clear' }) do
    Config.Log.actions[a] = true
end
