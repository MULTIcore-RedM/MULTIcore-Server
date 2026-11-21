-- ============================================================
-- MULTIhorses settings
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- Based on rsg-horses by Phil (see README.md, Credits).
-- Wild horse sellers are in config/wildhorse.lua, the horses for sale
-- in shared/horse_settings.lua, tack pieces in shared/horse_comp.lua.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = setr multicore_locale, else English)
Config.Debug  = false               -- default false (extra prints in F8 / the server console)

---------------------------------
-- money
---------------------------------
Config.Currency = 'cash'            -- default 'cash' (money type players pay with and are paid in)
Config.SellBack = 0.5               -- default 0.5 (a stable buys a horse back for this share of its price)

---------------------------------
-- stables: interaction
---------------------------------
Config.Interact       = 'auto'      -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target'; 'prompt')
Config.KeyBind        = 'J'         -- default 'J' (key name from MULTIcore's shared/keybinds.lua; prompts only)
Config.TargetIcon     = 'fas fa-horse' -- default 'fas fa-horse' (MULTItarget icon on the stable hand)
Config.TargetDistance = 2.5         -- default 2.5 (how close to stand to the stable hand for MULTItarget)
Config.PromptDistance = 2.5         -- default 2.5 (metres from the stable hand at which the prompt shows; prompt mode)
Config.StableDistance = 30.0        -- default 30.0 (the server refuses stable actions farther than this from the stable; 0 = off)
Config.BuyStables       = { valentine = true } -- stables that sell horses (each needs horsePreview + horseCameraPreview below)
Config.CustomizeStables = { valentine = true } -- stables that offer tack and coat customization

---------------------------------
-- horse shop (stable menu "Horse Shop")
---------------------------------
Config.ShopItems = {
    { name = 'horse_brush',     amount = 10, price = 5 },
    { name = 'horse_lantern',   amount = 10, price = 10 },
    { name = 'horsecarrot',     amount = 50, price = 1 },
    { name = 'horseapple',      amount = 50, price = 1 },
    { name = 'hay',             amount = 50, price = 1 },
    { name = 'horse_stimulant', amount = 25, price = 2 },
    { name = 'horse_reviver',   amount = 25, price = 10 },
    { name = 'horse_holster',   amount = 25, price = 20 },
}

-- Items this script needs that MULTIcore's shared/items.lua may not have.
-- Each is added at start through MULTIinventory only when it is missing. weight = grams.
Config.NewItems = {
    hay           = { name = 'hay',           label = 'Hay',           weight = 300, type = 'item', image = 'hay.png',           unique = false, useable = true, shouldClose = true, description = 'Feed for horses, used in breeding',        category = 'horse' },
    horsecarrot   = { name = 'horsecarrot',   label = 'Carrot',        weight = 100, type = 'item', image = 'horsecarrot.png',   unique = false, useable = true, shouldClose = true, description = 'Feed for horses',                          category = 'horse' },
    horseapple    = { name = 'horseapple',    label = 'Apple',         weight = 100, type = 'item', image = 'horseapple.png',    unique = false, useable = true, shouldClose = true, description = 'Feed for horses',                          category = 'horse' },
    horse_holster = { name = 'horse_holster', label = 'Horse Holster', weight = 800, type = 'item', image = 'horse_holster.png', unique = false, useable = true, shouldClose = true, description = 'Holster for storing long arms on a horse', category = 'horse' },
}

Config.HorseHolster = {
    hash         = 0xF772CED6,      -- holster shop item hash
    categoryHash = 0x80451C25,      -- saddlebags category hash
}

---------------------------------
-- game key prompts on the horse and while leading it (bottom right of the screen)
---------------------------------
Config.Prompt = {
    HorseDrink = 0xD8CF0C95,
    HorseGraze = 0xD8CF0C95,
    HorseLay = 0xD8CF0C95,
    HorsePlay = 0x620A6C5E,
    HorseSaddleBag = 0xC7B5340A,
    HorseBrush = 0x63A38F2C,
    HorseLantern = 0x63A38F2C,
    Rotate = { 0x7065027D, 0xB4E465B4 },
}

Config.TrickXp = {
    Lay = 1000,                     -- default 1000 (horse xp needed for the "Lay" trick)
    Play = 2000,                    -- default 2000 (horse xp needed for the "Play" trick)
}

---------------------------------
-- tack categories and prices (customization)
---------------------------------
Config.ComponentHash = {
    Blankets = 0x17CEB41A,
    Saddles = 0xBAA7E618,
    Horns = 0x05447332,
    Saddlebags = 0x80451C25,
    Stirrups = 0xDA6DADCA,
    Bedrolls = 0xEFB31921,
    Tails = 0xA63CAE10,
    Manes = 0xAA0217AB,
    Masks = 0xD3500E5D,
    Mustaches = 0x30DEFDDF,
    Bridles = 0x94B2E3AF,
    Horseshoes = 0xFACFC3C0,
}

-- price per category: charged once for every category changed on save (checked on the server)
Config.PriceComponent = {
    Blankets = 15,
    Saddles = 75,
    Horns = 40,
    Saddlebags = 35,
    Stirrups = 30,
    Bedrolls = 20,
    Tails = 12,
    Manes = 14,
    Masks = 18,
    Mustaches = 10,
    Bridles = 25,
    Horseshoes = 8,
}

---------------------------------
-- coat colour / markings
-- tint0 = main coat colour (0-254), tint1 = markings (0-255), tint2 = nose (0-255)
-- mane / tail = mane and tail colours (0-254)
---------------------------------
Config.Coat = {
    Price = 100,                    -- default 100 (fee for a custom, non-preset main colour)
    Palette = 'metaped_tint_horse',
    Default = { tint0 = 0, tint1 = 255, tint2 = 255, mane = 0, tail = 0 },
}

-- preset main colours: natural coats cheap, dyes dearer. One coat fee per save,
-- priced by the main colour picked. Their names are in the locales (nui_color_...).
Config.CoatPresets = {
    { name = 'White',        tint0 = 0,   price = 30 },
    { name = 'Black',        tint0 = 9,   price = 40 },
    { name = 'Brown',        tint0 = 40,  price = 35 },
    { name = 'Bay',          tint0 = 100, price = 45 },
    { name = 'Chestnut Red', tint0 = 127, price = 50 },
    { name = 'Silver',       tint0 = 128, price = 60 },
    { name = 'Grey',         tint0 = 130, price = 55 },
    { name = 'Bronze',       tint0 = 121, price = 120 },
    { name = 'Blood Red',    tint0 = 125, price = 140 },
    { name = 'Orange',       tint0 = 120, price = 150 },
    { name = 'Yellow',       tint0 = 119, price = 160 },
    { name = 'Green',        tint0 = 112, price = 170 },
    { name = 'Blue',         tint0 = 110, price = 180 },
    { name = 'Dark Green',   tint0 = 109, price = 180 },
    { name = 'Lime',         tint0 = 115, price = 190 },
    { name = 'Pink',         tint0 = 107, price = 200 },
    { name = 'Purple',       tint0 = 105, price = 200 },
    { name = 'Lilac',        tint0 = 108, price = 220 },
}

---------------------------------
-- general
---------------------------------
Config.Automount           = false  -- default false (mount the horse as soon as it arrives)
Config.SpawnOnRoadOnly     = false  -- default false (a called horse only comes when a road is near)
Config.CheckCycle          = 30     -- default 30 (minutes between old-age checks)
Config.StarterHorseModel   = 'a_c_horse_mp_mangy_backup' -- the starter horse model
Config.StarterHorseDieAge  = 7      -- default 7 (days a starter horse lives; 0 = forever)
Config.HorseDieAge         = 665    -- default 665 (days any other horse lives; 0 = forever)
Config.OldAgeTelegram      = true   -- default true (the owner gets a telegram when a horse dies of old age; MULTItelegram makes the table)
Config.StoreFleedHorse     = false  -- default false (a horse sent away goes back to the nearest stable)
Config.EnableServerNotify  = false  -- default false (prints when the old-age check ran)
Config.AllowTwoPlayersRide = true   -- default true (a second player can ride along)
Config.DeathGracePeriod    = 60000  -- default 60000 (ms a fallen horse can still be revived with a horse reviver)
Config.DeleteDeadHorse     = false  -- true = a horse that is not revived in time is gone for good;
                                    --   false = it goes back to its stable and can be called again)
Config.MoveHorseBasePrice  = 10     -- default 10 (dollars for every move to another stable)
Config.MoveFeePerMeter     = 0.01   -- default 0.01 (dollars per metre between the two stables)
Config.WhistleKey          = 'H'    -- default 'H' (key name from MULTIcore's shared/keybinds.lua; H = the game's whistle)

---------------------------------
-- saddlebags (one MULTIinventory inventory per horse: custom:horse_<horseid>)
---------------------------------
Config.SaddlebagsNeedTack       = true -- default true (the saddlebags open only while the horse wears a saddle and saddlebags)
Config.SellNeedsEmptySaddlebags = true -- default true (a horse can't be sold while its saddlebags hold anything;
                                       --   false = whatever is in them is lost when it is sold)

-- saddlebag size by horse level (weight in grams)
Config.Level1InvWeight = 4000
Config.Level1InvSlots = 14
Config.Level2InvWeight = 6000
Config.Level2InvSlots = 16
Config.Level3InvWeight = 8000
Config.Level3InvSlots = 18
Config.Level4InvWeight = 9000
Config.Level4InvSlots = 20
Config.Level5InvWeight = 10000
Config.Level5InvSlots = 25
Config.Level6InvWeight = 12000
Config.Level6InvSlots = 26
Config.Level7InvWeight = 13000
Config.Level7InvSlots = 27
Config.Level8InvWeight = 14000
Config.Level8InvSlots = 28
Config.Level9InvWeight = 15000
Config.Level9InvSlots = 29
Config.Level10InvWeight = 16000
Config.Level10InvSlots = 30

---------------------------------
-- horse health / stamina / speed / acceleration points by level
---------------------------------
Config.Level1 = 100
Config.Level2 = 200
Config.Level3 = 300
Config.Level4 = 400
Config.Level5 = 500
Config.Level6 = 900
Config.Level7 = 1000
Config.Level8 = 1500
Config.Level9 = 1750
Config.Level10 = 2000

---------------------------------
-- feeding (use the item from the satchel next to the horse)
-- medicineHash is optional (default consumable_horse_stimulant)
---------------------------------
Config.HorseFeed = {
    ['horsecarrot']     = { health = 10,  stamina = 10,  ismedicine = false },
    ['hay']             = { health = 10,  stamina = 10,  ismedicine = false },
    ['horseapple']      = { health = 15,  stamina = 15,  ismedicine = false },
    ['horse_carrot']    = { health = 10,  stamina = 10,  ismedicine = false },  -- MULTIcore item names
    ['horse_apple']     = { health = 15,  stamina = 15,  ismedicine = false },
    ['haysnack']        = { health = 10,  stamina = 15,  ismedicine = false },
    ['horsemeal']       = { health = 25,  stamina = 25,  ismedicine = false },
    ['horse_stimulant'] = { health = 100, stamina = 100, ismedicine = true, medicineHash = 'consumable_horse_stimulant' },
}

---------------------------------
-- horse xp for feeding / brushing (given by the server)
-- CooldownSeconds is per horse (0 = off), MaxXp caps horsexp
---------------------------------
Config.HorseXp = {
    CooldownSeconds = 60,
    MaxXp = 2000,
    Brush = 10,
    Feed = {
        ['horsecarrot'] = 5,
        ['hay'] = 5,
        ['horseapple'] = 10,
        ['horse_carrot'] = 5,
        ['horse_apple'] = 10,
        ['haysnack'] = 5,
        ['horsemeal'] = 10,
        ['horse_stimulant'] = 15,
    },
    -- leading the horse to water / a trough / a hay pile: nothing is used up,
    -- the same per-horse cooldown applies
    Drink = 3,
    Graze = 5,
}

---------------------------------
-- leading the horse to water, troughs and hay piles
---------------------------------
Config.ObjectAction = true          -- default true

Config.BoostAction = {
    Health = math.random(3, 9),
    Stamina = math.random(3, 9)
}

Config.ObjectActionList = {
    [1] = { `p_watertrough02x`, 'drink' },
    [2] = { `p_watertrough01x`, 'drink' },
    [3] = { `p_haypile01x`, 'feed' },
}

Config.Anim = {
    Drink  = { dict = 'amb_creature_mammal@world_horse_drink_ground@base', anim = 'base',   duration = 20 }, -- duration in seconds
    Drink2 = { dict = 'amb_creature_mammal@prop_horse_drink_trough@idle0', anim = 'idle_a', duration = 20 },
    Graze  = { dict = 'amb_creature_mammal@world_horse_grazing@idle',      anim = 'idle_a', duration = 20 }
}

---------------------------------
-- map blips (the name comes from the locales: cf_menu_horse_blip_name)
---------------------------------
Config.Blip = {
    blipSprite = 'blip_shop_horse',
    blipScale = 0.1,
}

---------------------------------
-- stable hands
---------------------------------
Config.DistanceSpawn = 20.0         -- default 20.0 (the stable hand is made when the player is this close)
Config.FadeIn = true                -- default true

---------------------------------
-- breeding
---------------------------------
Config.Breeding = {
    enabled = true,
    requiredJob = 'horsebreeder',   -- '' = anyone may breed
    requireOppositeSex = true,
    gestationMinutes = 120,
    breedCooldownMinutes = 120,
    hayCost = 1,
    maturityMinutes = 60,
}

---------------------------------
-- foals growing up
---------------------------------
Config.Growth = {
    enabled = true,
    minScale = 0.4,
    growthMinutesToAdult = 720,     -- 12 hours
}

---------------------------------
-- commands ('' = off)
---------------------------------
Config.Commands = {
    FindHorse   = 'findhorse',      -- lists your horses and where they stand (MULTIradial uses it)
    FleeHorse   = 'fleehorse',      -- sends your horse away (MULTIradial uses it)
    Rename      = 'sethorsename',   -- renames your active horse
    AcceptTrade = 'accepttrade',    -- takes a horse someone offered you
    Seat        = 'seat',           -- /seat 2: change seats on a horse or wagon
}

---------------------------------
-- Discord logs (off by default: fill in the URLs and set Enabled = true)
---------------------------------
Config.Webhooks = {
    Enabled = false,
    BotName = 'MULTIhorses',
    BotAvatar = '',                 -- optional image URL
    URLs = {
        economy  = '', -- purchases, sales, stabling, shop, weapons on the horse, wild horse rewards
        horses   = '', -- feeding, brushing, reviving, customization, deaths, moves
        security = '', -- refused or invalid requests
        general  = '', -- everything else
    },
}

---------------------------------
-- stables
-- stableid: saved in player_horses.stable; the name comes from the locales (stable_<stableid>)
-- horsecustom: where the horse stands while it is customized
-- horsePreview / horseCameraPreview: the horse and camera while buying (stables in Config.BuyStables)
---------------------------------
Config.StableSettings = {
    { stableid = 'colter',       coords = vector3(-1334.2, 2397.41, 307.21),  npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(-1334.2, 2397.41, 307.21, 67.43),   horsecustom = vec4(-1344.8345, 2392.2900, 306.7908, 153.3136), showblip = true },
    { stableid = 'vanhorn',      coords = vector3(2968.86, 792.97, 51.4),     npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(2968.86, 792.97, 51.4, 357.89),     horsecustom = vec4(2970.4155, 785.6143, 51.3995, 137.7870),    showblip = true },
    { stableid = 'saintdenis',   coords = vector3(2512.28, -1457.33, 46.31),  npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(2512.28, -1457.33, 46.31, 86.43),   horsecustom = vec4(2502.7288, -1439.7654, 46.3141, 176.4436),  showblip = true },
    { stableid = 'rhodes',       coords = vector3(1211.55, -190.84, 101.39),  npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(1211.55, -190.84, 101.39, 100.22),  horsecustom = vec4(1215.1134, -207.5254, 101.0958, 267.8741),  showblip = true },
    { stableid = 'valentine',    coords = vector3(-365.2, 791.94, 116.18),    npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(-365.2, 791.94, 116.18, 180.9),     horsecustom = vec4(-388.5212, 784.0562, 115.8154, 150.4135),
      horsePreview = vec4(-357.77, 771.73, 116.52, 5.00), horseCameraPreview = vec4(-357.77, 764.73, 118.52, 5.00), showblip = true },
    { stableid = 'strawberry',   coords = vector3(-1817.1, -568.64, 155.98),  npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(-1817.1, -568.64, 155.98, 254.85),  horsecustom = vec4(-1827.2969, -577.0493, 155.9565, 215.5404),  showblip = true },
    { stableid = 'blackwater',   coords = vector3(-876.85, -1365.55, 43.53),  npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(-876.85, -1365.55, 43.53, 275.38),  horsecustom = vec4(-865.1928, -1366.3270, 43.5440, 86.8795),    showblip = true },
    { stableid = 'tumbleweed',   coords = vector3(-5514.81, -3040.25, -2.39), npcmodel = `u_m_m_bwmstablehand_01`,   npccoords = vector4(-5514.81, -3040.25, -2.39, 175.22), horsecustom = vec4(-5526.3452, -3030.7842, -2.0329, 105.3392), showblip = true },
    { stableid = 'emeraldranch', coords = vector3(1393.46, 353.09, 87.63),    npcmodel = `mp_de_u_f_m_doverhill_01`, npccoords = vector4(1393.90, 354.29, 87.66, 151.53),    horsecustom = vec4(1396.73, 345.73, 87.58, 58.91),             showblip = true },
}

-- where a horse goes when it has no stable (a starter horse another script made, a saved wild horse)
Config.DefaultStable = 'valentine'

---------------------------------
-- horse models a foal can be born as
---------------------------------
Config.HorseModels = {
    'a_c_horse_americanpaint_greyovero',
    'a_c_horse_americanpaint_overo',
    'a_c_horse_americanpaint_splashedwhite',
    'a_c_horse_americanpaint_tobiano',
    'a_c_horse_americanstandardbred_black',
    'a_c_horse_americanstandardbred_buckskin',
    'a_c_horse_americanstandardbred_lightbuckskin',
    'a_c_horse_americanstandardbred_palominodapple',
    'a_c_horse_americanstandardbred_silvertailbuckskin',
    'a_c_horse_andalusian_darkbay',
    'a_c_horse_andalusian_perlino',
    'a_c_horse_andalusian_rosegray',
    'a_c_horse_appaloosa_blanket',
    'a_c_horse_appaloosa_blacksnowflake',
    'a_c_horse_appaloosa_brownleopard',
    'a_c_horse_appaloosa_fewspotted_pc',
    'a_c_horse_appaloosa_leopard',
    'a_c_horse_appaloosa_leopardblanket',
    'a_c_horse_arabian_black',
    'a_c_horse_arabian_grey',
    'a_c_horse_arabian_redchestnut',
    'a_c_horse_arabian_redchestnut_pc',
    'a_c_horse_arabian_rosegreybay',
    'a_c_horse_arabian_warpedbrindle_pc',
    'a_c_horse_arabian_white',
    'a_c_horse_ardennes_bayroan',
    'a_c_horse_ardennes_irongreyroan',
    'a_c_horse_ardennes_strawberryroan',
    'a_c_horse_belgian_blondchestnut',
    'a_c_horse_belgian_mealychestnut',
    'a_c_horse_breton_grullodun',
    'a_c_horse_breton_mealydapplebay',
    'a_c_horse_breton_redroan',
    'a_c_horse_breton_sealbrown',
    'a_c_horse_breton_sorrel',
    'a_c_horse_breton_steelgrey',
    'a_c_horse_criollo_baybrindle',
    'a_c_horse_criollo_bayframeovero',
    'a_c_horse_criollo_blueroanovero',
    'a_c_horse_criollo_dun',
    'a_c_horse_criollo_marblesabino',
    'a_c_horse_criollo_sorrelovero',
    'a_c_horse_dutchwarmblood_chocolateroan',
    'a_c_horse_dutchwarmblood_sealbrown',
    'a_c_horse_dutchwarmblood_sootybuckskin',
    'a_c_horse_gypsycob_skewbald',
    'a_c_horse_gypsycob_splashedpiebald',
    'a_c_horse_gypsycob_whiteblagdon',
    'a_c_horse_hungarianhalfbred_darkdapplegrey',
    'a_c_horse_hungarianhalfbred_flaxenchestnut',
    'a_c_horse_hungarianhalfbred_liverchestnut',
    'a_c_horse_hungarianhalfbred_piebaldtobiano',
    'a_c_horse_kentuckysaddle_black',
    'a_c_horse_kentuckysaddle_buttermilkbuckskin_pc',
    'a_c_horse_kentuckysaddle_chestnutpinto',
    'a_c_horse_kentuckysaddle_grey',
    'a_c_horse_kentuckysaddle_silverbay',
    'a_c_horse_kladruber_black',
    'a_c_horse_kladruber_cremello',
    'a_c_horse_kladruber_dapplerosegrey',
    'a_c_horse_kladruber_grey',
    'a_c_horse_kladruber_silver',
    'a_c_horse_kladruber_white',
    'a_c_horse_missourifoxtrotter_amberchampagne',
    'a_c_horse_missourifoxtrotter_buckskinbrindle',
    'a_c_horse_missourifoxtrotter_dapplegrey',
    'a_c_horse_missourifoxtrotter_sablechampagne',
    'a_c_horse_missourifoxtrotter_silverdapplepinto',
    'a_c_horse_morgan_bay',
    'a_c_horse_morgan_bayroan',
    'a_c_horse_morgan_flaxenchestnut',
    'a_c_horse_morgan_liverchestnut_pc',
    'a_c_horse_morgan_palomino',
    'a_c_horse_mustang_goldendun',
    'a_c_horse_mustang_grullodun',
    'a_c_horse_mustang_reddunovero',
    'a_c_horse_mustang_tigerstripedbay',
    'a_c_horse_mustang_wildbay',
    'a_c_horse_nokota_blueroan',
    'a_c_horse_nokota_reversedappleroan',
    'a_c_horse_nokota_whiteroan',
    'a_c_horse_norfolkroadster_piebaldroan',
    'a_c_horse_norfolkroadster_speckledgrey',
    'a_c_horse_norfolkroadster_spottedtricolor',
    'a_c_horse_shire_darkbay',
    'a_c_horse_shire_lightgrey',
    'a_c_horse_shire_ravenblack',
    'a_c_horse_suffolkpunch_redchestnut',
    'a_c_horse_suffolkpunch_sorrel',
    'a_c_horse_tennesseewalker_blackrabicano',
    'a_c_horse_tennesseewalker_chestnut',
    'a_c_horse_tennesseewalker_dapplebay',
    'a_c_horse_tennesseewalker_flaxenroan',
    'a_c_horse_tennesseewalker_goldpalomino_pc',
    'a_c_horse_tennesseewalker_mahoganybay',
    'a_c_horse_tennesseewalker_redroan',
    'a_c_horse_thoroughbred_blackchestnut',
    'a_c_horse_thoroughbred_bloodbay',
    'a_c_horse_thoroughbred_brindle',
    'a_c_horse_thoroughbred_dapplegrey',
    'a_c_horse_thoroughbred_reversedappleblack',
    'a_c_horse_turkoman_darkbay',
    'a_c_horse_turkoman_gold',
    'a_c_horse_turkoman_silver',
}
