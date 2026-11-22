-- ============================================================
-- MULTIhouses settings
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- Every line a player sees is in locales/<lang>.lua.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = MULTIcore's language (MULTIConfig.Language), else English)
Config.Debug  = false               -- default false (extra prints in F8 / the server console)

---------------------------------
-- money and ownership
---------------------------------
Config.Currency           = 'cash'  -- default 'cash' (money type players pay with and are paid in)
Config.MaxHousesPerPlayer = 1       -- default 1 (houses one character may own at the same time)
Config.DepositPercent     = 20      -- default 20 (share of the price paid when buying; the rest is the balance)
Config.SellBack           = 0.8     -- default 0.8 (selling pays this share of the price, minus any balance still owed)
Config.BalanceGracePeriod = 2592000 -- default 2592000 (seconds after buying, 30 days, before an unpaid balance takes the house back)
Config.BalanceReminderInterval = 86400000 -- default 86400000 (ms, 24 hours, between balance reminder telegrams)

---------------------------------
-- land tax (property credit)
---------------------------------
Config.BillingEnabled  = false      -- default false (true = every cycle takes LandTaxPerCycle from each house's credit)
Config.BillingCycle    = 360        -- default 360 (hours between two tax cycles)
Config.LandTaxPerCycle = 5          -- default 5 (credit taken per house per cycle)
Config.StartCredit     = 10         -- default 10 (credit a house starts with when bought)
Config.CreditWarning   = 5          -- default 5 (a warning telegram goes out when credit < LandTaxPerCycle x this)
Config.MaxCredit       = 100000     -- default 100000 (most credit one house may hold)

---------------------------------
-- storage (MULTIinventory)
---------------------------------
Config.StorageMaxWeight = 4000000   -- default 4000000 (grams; MULTIinventory counts weight in grams, so 4000 kg)
Config.StorageMaxSlots  = 48        -- default 48 (slots in a house stash)
Config.PurgeStorage     = false     -- default false (true = the stash is emptied when a house is sold, released or taken back)

---------------------------------
-- blips
---------------------------------
Config.ShowBlips        = true      -- default true (false = no house blips at all)
Config.OwnedHouseBlips  = false     -- default false (true = only houses you hold a key to get a blip)
Config.BlipStyle        = 1664425300 -- default 1664425300 (BlipAddForCoords style)
Config.BlipForSale      = 'blip_proc_home'        -- default 'blip_proc_home' (sprite of a house for sale)
Config.BlipOwned        = 'blip_proc_home_locked' -- default 'blip_proc_home_locked' (sprite of an owned house)
Config.BlipScaleForSale = 0.2       -- default 0.2
Config.BlipScaleOwned   = 0.4       -- default 0.4

---------------------------------
-- interaction (MULTItarget, hold Left Alt)
---------------------------------
Config.Interact       = 'auto'      -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target'; 'prompt')
Config.HouseKey       = 'G'         -- default 'G' (prompt key at the house point; prompt mode only)
Config.DoorKey        = 'ENTER'     -- default 'ENTER' (prompt key at a door; prompt mode only)
Config.TargetRadius   = 1.5         -- default 1.5 (size of the MULTItarget point at the house and the doors)
Config.TargetDistance = 2.5         -- default 2.5 (how close to stand for MULTItarget)
Config.PromptDistance = 2.0         -- default 2.0 (metres at which a prompt shows; prompt mode)
Config.ServerDistance = 10.0        -- default 10.0 (the server refuses house menu, stash, outfits, buy and sell farther than this from the house point)
Config.DoorDistance   = 6.0         -- default 6.0 (the server refuses lock / unlock and lockpicking farther than this from the door)
Config.DoorRefreshSeconds = 30      -- default 30 (how often a client asks for every door state again)
Config.AdminPermission = 'admin'    -- default 'admin' (permission for /removehouse and releasing any house)

---------------------------------
-- break-ins
---------------------------------
Config.Robbery = {
    Enabled             = true,     -- default true (false = no lockpicking of house doors)
    RequireLockpick     = true,     -- default true (a lockpick item is needed)
    LockpickItem        = 'lockpick', -- default 'lockpick'
    RegisterItem        = true,     -- default true (add the lockpick to MULTIinventory's item list when it is missing)
    ItemWeight          = 50,       -- default 50 (grams; only when this script adds the item)
    LockpickBreakChance = 10,       -- default 10 (percent chance the lockpick breaks on an attempt)
    UseUpOnSuccess      = true,     -- default true (a picked lock uses up the lockpick)
    PickSeconds         = 30,       -- default 30 (length of the lockpicking progress bar)
    SkillCheck          = { 'easy' }, -- default { 'easy' } (ox_lib skill check rounds after the bar)
    SkillKeys           = { 'w' },  -- default { 'w' }
    CooldownPerHouse    = 30,       -- default 30 (minutes before the same house can be broken into again)
    GlobalCooldown      = 5,        -- default 5 (minutes before the same player can break in again)
    OnlyRobOwnedHouses  = false,    -- default false (true = only houses somebody owns can be broken into)
    RobberyMinutes      = 5,        -- default 5 (the door stays open this long, then locks again)
    LeaveDistance       = 50.0,     -- default 50.0 (walking farther than this from the house ends the break-in)
    PoliceAlert         = false,    -- default false (true = MULTIlaw alerts the law on every attempt)
}

---------------------------------
-- commands ('' = off)
---------------------------------
Config.Commands = {
    endRobbery   = 'endrob',        -- ends your own break-in and locks the door again
    fixNui       = 'fixnui',        -- closes the house page if it got stuck
    releaseHouse = 'releasehouse',  -- /releasehouse <number>: give up your house for nothing
    removeHouse  = 'removehouse',   -- admins: take a house away from its owner
}

---------------------------------
-- logs (MULTIserver, Discord)
---------------------------------
Config.LogName = 'houses'           -- default 'houses' (MULTIserver log name; '' = no logs)

---------------------------------
-- houses
-- houseid    id in the multi_houses table (the price is kept there)
-- menucoords the house point (buy, house menu, stash, outfits, telegrams)
-- blipcoords where the map blip sits
-- showblip   false = no blip for this house
-- label      optional name of your own; without it the house is called "House <number>"
---------------------------------
Config.Houses = {
    { houseid = 'house1', menucoords = vector3(220.0229, 984.5884, 190.8946), blipcoords = vector3(215.8, 988.0651, 189.9015), showblip = true },
    { houseid = 'house2', menucoords = vector3(-608.9351, -33.6887, 85.9955), blipcoords = vector3(-615.9397, -27.0866, 84.9976), showblip = true },
    { houseid = 'house3', menucoords = vector3(1887.1403, 300.5607, 77.0666), blipcoords = vector3(1888.17, 297.9592, 76.0762), showblip = true },
    { houseid = 'house4', menucoords = vector3(1787.467, -81.5481, 56.8024), blipcoords = vector3(1781.1064, -89.1156, 55.816), showblip = true },
    { houseid = 'house5', menucoords = vector3(1269.6508, -412.1731, 97.5967), blipcoords = vector3(1264.1952, -404.071, 96.595), showblip = true },
    { houseid = 'house6', menucoords = vector3(1619.2441, -364.0213, 75.8972), blipcoords = vector3(1627.2501, -366.2561, 74.9099), showblip = true },
    { houseid = 'house7', menucoords = vector3(-2367.865, -2394.804, 62.2783), blipcoords = vector3(-2368.8418, -2390.4062, 61.5202), showblip = true },
    { houseid = 'house8', menucoords = vector3(1120.2464, 492.6977, 97.2842), blipcoords = vector3(1114.0626, 493.7463, 96.2909), showblip = true },
    { houseid = 'house9', menucoords = vector3(-60.77, -390.1, 72.22), blipcoords = vector3(-64.2426, -393.5611, 71.2487), showblip = true },
    { houseid = 'house10', menucoords = vector3(339.8875, -667.7122, 42.811), blipcoords = vector3(338.2534, -669.9484, 41.8211), showblip = true },
    { houseid = 'house11', menucoords = vector3(1111.6049, -1304.963, 66.4036), blipcoords = vector3(1111.4659, -1297.5782, 65.4183), showblip = true },
    { houseid = 'house12', menucoords = vector3(1369.3358, -870.8798, 70.1273), blipcoords = vector3(1365.4198, -872.8802, 69.1621), showblip = true },
    { houseid = 'house13', menucoords = vector3(2064.4531, -854.3615, 43.361), blipcoords = vector3(2068.3599, -847.3214, 42.3509), showblip = true },
    { houseid = 'house14', menucoords = vector3(2254.1096, -795.2846, 44.2263), blipcoords = vector3(2253.8467, -797.3051, 43.1331), showblip = true },
    { houseid = 'house15', menucoords = vector3(2373.1706, -862.4254, 43.0204), blipcoords = vector3(2370.9302, -857.4855, 42.0431), showblip = true },
    { houseid = 'house16', menucoords = vector3(1706.3145, -1004.643, 43.4735), blipcoords = vector3(1709.3989, -1003.7618, 42.4808), showblip = true },
    { houseid = 'house17', menucoords = vector3(2624.0607, 1696.1097, 115.7023), blipcoords = vector3(2628.2214, 1694.329, 114.6662), showblip = true },
    { houseid = 'house18', menucoords = vector3(2990.2619, 2184.7788, 166.7404), blipcoords = vector3(2993.4243, 2188.4375, 165.7357), showblip = true },
    { houseid = 'house19', menucoords = vector3(2477.8996, 1998.1372, 168.2523), blipcoords = vector3(2473.8528, 1996.4064, 167.226), showblip = true },
    { houseid = 'house20', menucoords = vector3(-422.9819, 1738.1881, 216.5589), blipcoords = vector3(-422.6643, 1733.5697, 215.59), showblip = true },
    { houseid = 'house21', menucoords = vector3(897.2836, 261.661, 116.0091), blipcoords = vector3(900.3438, 265.2184, 115.0481), showblip = true },
    { houseid = 'house22', menucoords = vector3(-1353.182, 2436.3557, 308.4051), blipcoords = vector3(-1347.9484, 2435.2036, 307.4961), showblip = true },
    { houseid = 'house23', menucoords = vector3(-553.2758, 2701.4128, 320.4156), blipcoords = vector3(-556.4168, 2698.8635, 319.3802), showblip = true },
    { houseid = 'house24', menucoords = vector3(-1021.677, 1695.299, 244.3102), blipcoords = vector3(-1019.1106, 1688.299, 243.2798), showblip = true },
    { houseid = 'house25', menucoords = vector3(-1819.195, 657.8708, 131.8598), blipcoords = vector3(-1815.1489, 654.9638, 130.8825), showblip = true },
    { houseid = 'house26', menucoords = vector3(-2173.403, 715.4107, 122.6187), blipcoords = vector3(-2182.511, 716.4636, 121.6288), showblip = true },
    { houseid = 'house27', menucoords = vector3(-2579.494, -1380.417, 149.2548), blipcoords = vector3(-2575.8262, -1379.3583, 148.2723), showblip = true },
    { houseid = 'house28', menucoords = vector3(-2375.747, -1591.876, 154.2863), blipcoords = vector3(-2374.3643, -1592.6022, 153.2996), showblip = true },
    { houseid = 'house29', menucoords = vector3(-1410.868, -2671.971, 42.1715), blipcoords = vector3(-1410.5718, -2674.2229, 41.1852), showblip = true },
    { houseid = 'house30', menucoords = vector3(-3960.028, -2124.254, -4.0764), blipcoords = vector3(-3958.3901, -2129.394, -5.2355), showblip = true },
    { houseid = 'house31', menucoords = vector3(-4370.378, -2415.955, 20.3996), blipcoords = vector3(-4366.0122, -2416.3057, 19.4234), showblip = true },
    { houseid = 'house32', menucoords = vector3(-5549.529, -2399.353, -8.7457), blipcoords = vector3(-5552.1465, -2401.5205, -9.7141), showblip = true },
    { houseid = 'house33', menucoords = vector3(-3550.882, -3008.228, 11.8875), blipcoords = vector3(-3552.3843, -3012.0999, 10.8203), showblip = true },
    { houseid = 'house34', menucoords = vector3(-1962.949, 2157.6286, 327.5801), blipcoords = vector3(-1959.1854, 2160.2043, 326.5538), showblip = true },
    { houseid = 'house35', menucoords = vector3(-1488.904, 1248.895, 314.4904), blipcoords = vector3(-1494.4031, 1246.7662, 313.5432), showblip = true },
    { houseid = 'house36', menucoords = vector3(3028.9965, 1780.9338, 84.1277), blipcoords = vector3(3024.1213, 1777.0731, 83.1691), showblip = true },
    { houseid = 'house37', menucoords = vector3(1984.8593, 1196.9948, 171.4021), blipcoords = vector3(1981.9653, 1195.0834, 170.4178), showblip = true },
    { houseid = 'house38', menucoords = vector3(2718.0898, 710.0052, 79.5433), blipcoords = vector3(2716.8154, 708.1669, 78.6052), showblip = true },
    { houseid = 'house39', menucoords = vector3(2823.6367, 275.3895, 48.0969), blipcoords = vector3(2824.4971, 270.8991, 47.1208), showblip = true },
    { houseid = 'house40', menucoords = vector3(1391.1662, -2085.114, 52.5663), blipcoords = vector3(1387.302, -2077.4402, 51.5811), showblip = true },
    { houseid = 'house42', menucoords = vector3(1700.9014, 1512.7069, 147.8697), blipcoords = vector3(1697.4684, 1508.2377, 146.8824), showblip = true },
    { houseid = 'house43', menucoords = vector3(-3402.104, -3304.445, -4.458), blipcoords = vector3(-3400.0259, -3302.1235, -5.3949), showblip = true },
    { houseid = 'house44', menucoords = vector3(-819.3696, 356.0723, 98.0784), blipcoords = vector3(-818.6138, 351.1617, 97.1088), showblip = true },
    { houseid = 'house45', menucoords = vector3(2712.8942, -1288.714, 60.345), blipcoords = vector3(2711.437, -1293.0839, 59.4585), showblip = true },
    { houseid = 'house46', menucoords = vector3(-2593.626, 461.1626, 146.9973), blipcoords = vector3(-2597.7019, 457.8384, 146.014), showblip = true },
    { houseid = 'house47', menucoords = vector3(2235.07, -141.05, 47.62), blipcoords = vector3(2234.82, -146.91, 47.64), showblip = true },
    { houseid = 'house48', menucoords = vector3(-1637.3, -1357.7, 84.42), blipcoords = vector3(-1639.18, -1356.54, 84.43), showblip = true },
    { houseid = 'house49', menucoords = vector3(2309.91, -328.61, 41.9), blipcoords = vector3(2309.91, -328.61, 41.9), showblip = true },
    { houseid = 'house50', menucoords = vector3(1133.9, -981.28, 69.4), blipcoords = vector3(1133.9, -981.28, 69.4), showblip = true },
    { houseid = 'house51', menucoords = vector3(777.64, 848.32, 121.92), blipcoords = vector3(777.64, 848.32, 121.92), showblip = true },
}

---------------------------------
-- house doors (game door hashes)
-- Locked while a house is owned, open while it is for sale.
-- Key holders lock and unlock them.
---------------------------------
Config.HouseDoors = {
    { houseid = 'house1', doorid = 3598523785, doorcoords = vector3(215.8, 988.0651, 189.9015) },
    { houseid = 'house1', doorid = 2031215067, doorcoords = vector3(222.8266, 990.534, 189.9015) },
    { houseid = 'house2', doorid = 1189146288, doorcoords = vector3(-615.9397, -27.0866, 84.9976) },
    { houseid = 'house2', doorid = 906448125, doorcoords = vector3(-608.7385, -26.6129, 84.9976) },
    { houseid = 'house3', doorid = 2821676992, doorcoords = vector3(1888.17, 297.9592, 76.0762) },
    { houseid = 'house3', doorid = 1510914117, doorcoords = vector3(1891.0833, 302.622, 76.0916) },
    { houseid = 'house4', doorid = 3549587335, doorcoords = vector3(1781.1064, -89.1156, 55.816) },
    { houseid = 'house4', doorid = 3000692149, doorcoords = vector3(1781.3618, -82.6877, 55.7985) },
    { houseid = 'house4', doorid = 1928053488, doorcoords = vector3(1792.0642, -83.2238, 55.7985) },
    { houseid = 'house5', doorid = 772977516, doorcoords = vector3(1264.1952, -404.071, 96.595) },
    { houseid = 'house5', doorid = 527767089, doorcoords = vector3(1266.8379, -412.629, 96.595) },
    { houseid = 'house6', doorid = 3468185317, doorcoords = vector3(1627.2501, -366.2561, 74.9099) },
    { houseid = 'house7', doorid = 2779142555, doorcoords = vector3(-2368.8418, -2390.4062, 61.5202) },
    { houseid = 'house8', doorid = 1239033969, doorcoords = vector3(1114.0626, 493.7463, 96.2909) },
    { houseid = 'house8', doorid = 1597362984, doorcoords = vector3(1116.3992, 485.9921, 96.3063) },
    { houseid = 'house9', doorid = 1299456376, doorcoords = vector3(-64.2426, -393.5611, 71.2487) },
    { houseid = 'house10', doorid = 2933656395, doorcoords = vector3(338.2534, -669.9484, 41.8211) },
    { houseid = 'house10', doorid = 3238637478, doorcoords = vector3(347.2474, -666.0535, 41.8228) },
    { houseid = 'house11', doorid = 3544613794, doorcoords = vector3(1111.4659, -1297.5782, 65.4183) },
    { houseid = 'house11', doorid = 1485561723, doorcoords = vector3(1114.6072, -1305.0754, 65.4183) },
    { houseid = 'house12', doorid = 1511858696, doorcoords = vector3(1365.4198, -872.8802, 69.1621) },
    { houseid = 'house12', doorid = 1282705079, doorcoords = vector3(1376.0239, -873.2421, 69.1151) },
    { houseid = 'house13', doorid = 2238665296, doorcoords = vector3(2068.3599, -847.3214, 42.3509) },
    { houseid = 'house13', doorid = 2080980868, doorcoords = vector3(2069.7229, -847.315, 42.3509) },
    { houseid = 'house13', doorid = 2700347737, doorcoords = vector3(2064.3887, -847.3214, 42.3509) },
    { houseid = 'house13', doorid = 2544301759, doorcoords = vector3(2065.7515, -847.315, 42.3509) },
    { houseid = 'house13', doorid = 3720952508, doorcoords = vector3(2069.7219, -855.8794, 42.3509) },
    { houseid = 'house13', doorid = 350169319, doorcoords = vector3(2068.3589, -855.8857, 42.3509) },
    { houseid = 'house14', doorid = 984852093, doorcoords = vector3(2253.8467, -797.3051, 43.1331) },
    { houseid = 'house14', doorid = 3473362722, doorcoords = vector3(2257.2678, -792.7042, 43.1672) },
    { houseid = 'house14', doorid = 686097120, doorcoords = vector3(2257.9419, -786.5975, 43.1849) },
    { houseid = 'house14', doorid = 3107660458, doorcoords = vector3(2254.5459, -781.7354, 43.1655) },
    { houseid = 'house14', doorid = 3419719645, doorcoords = vector3(2252.3625, -781.6602, 43.1655) },
    { houseid = 'house15', doorid = 3945582303, doorcoords = vector3(2370.9302, -857.4855, 42.0431) },
    { houseid = 'house15', doorid = 862008394, doorcoords = vector3(2370.8708, -864.438, 42.0401) },
    { houseid = 'house16', doorid = 1661737397, doorcoords = vector3(1709.3989, -1003.7618, 42.4808) },
    { houseid = 'house17', doorid = 1574473390, doorcoords = vector3(2628.2214, 1694.329, 114.6662) },
    { houseid = 'house18', doorid = 3731688048, doorcoords = vector3(2993.4243, 2188.4375, 165.7357) },
    { houseid = 'house18', doorid = 344028824, doorcoords = vector3(2989.1082, 2193.7415, 165.7398) },
    { houseid = 'house19', doorid = 2652873387, doorcoords = vector3(2473.8528, 1996.4064, 167.226) },
    { houseid = 'house19', doorid = 2061942857, doorcoords = vector3(2472.6179, 2001.7778, 167.226) },
    { houseid = 'house20', doorid = 3702071668, doorcoords = vector3(-422.6643, 1733.5697, 215.59) },
    { houseid = 'house21', doorid = 1934463007, doorcoords = vector3(900.3438, 265.2184, 115.0481) },
    { houseid = 'house22', doorid = 2183007198, doorcoords = vector3(-1347.9484, 2435.2036, 307.4961) },
    { houseid = 'house22', doorid = 4288310487, doorcoords = vector3(-1348.2998, 2447.0854, 307.4806) },
    { houseid = 'house23', doorid = 872775928, doorcoords = vector3(-556.4168, 2698.8635, 319.3802) },
    { houseid = 'house23', doorid = 2385374047, doorcoords = vector3(-557.964, 2708.988, 319.4318) },
    { houseid = 'house24', doorid = 3167436574, doorcoords = vector3(-1019.1106, 1688.299, 243.2798) },
    { houseid = 'house25', doorid = 1195519038, doorcoords = vector3(-1815.1489, 654.9638, 130.8825) },
    { houseid = 'house26', doorid = 2212914984, doorcoords = vector3(-2182.511, 716.4636, 121.6288) },
    { houseid = 'house27', doorid = 562830153, doorcoords = vector3(-2575.8262, -1379.3583, 148.2723) },
    { houseid = 'house27', doorid = 663425326, doorcoords = vector3(-2578.7859, -1385.2465, 148.2622) },
    { houseid = 'house28', doorid = 1171581101, doorcoords = vector3(-2374.3643, -1592.6022, 153.2996) },
    { houseid = 'house29', doorid = 52014802, doorcoords = vector3(-1410.5718, -2674.2229, 41.1852) },
    { houseid = 'house30', doorid = 4164042403, doorcoords = vector3(-3958.3901, -2129.394, -5.2355) },
    { houseid = 'house31', doorid = 2047072501, doorcoords = vector3(-4366.0122, -2416.3057, 19.4234) },
    { houseid = 'house32', doorid = 2715667864, doorcoords = vector3(-5552.1465, -2401.5205, -9.7141) },
    { houseid = 'house32', doorid = 1263476860, doorcoords = vector3(-5555.2666, -2397.3523, -9.7149) },
    { houseid = 'house33', doorid = 1894337720, doorcoords = vector3(-3552.3843, -3012.0999, 10.8203) },
    { houseid = 'house33', doorid = 120764251, doorcoords = vector3(-3555.4402, -3007.9375, 10.8203) },
    { houseid = 'house34', doorid = 943176298, doorcoords = vector3(-1959.1854, 2160.2043, 326.5538) },
    { houseid = 'house35', doorid = 2971757040, doorcoords = vector3(-1494.4031, 1246.7662, 313.5432) },
    { houseid = 'house36', doorid = 1973911195, doorcoords = vector3(3024.1213, 1777.0731, 83.1691) },
    { houseid = 'house37', doorid = 784290387, doorcoords = vector3(1981.9653, 1195.0834, 170.4178) },
    { houseid = 'house38', doorid = 843137708, doorcoords = vector3(2716.8154, 708.1669, 78.6052) },
    { houseid = 'house39', doorid = 4275653891, doorcoords = vector3(2824.4971, 270.8991, 47.1208) },
    { houseid = 'house39', doorid = 1431398235, doorcoords = vector3(2820.5608, 278.9088, 50.0912) },
    { houseid = 'house40', doorid = 896012811, doorcoords = vector3(1387.302, -2077.4402, 51.5811) },
    { houseid = 'house40', doorid = 2813949612, doorcoords = vector3(1385.0637, -2085.1807, 51.5838) },
    { houseid = 'house42', doorid = 868379185, doorcoords = vector3(1697.4684, 1508.2377, 146.8824) },
    { houseid = 'house42', doorid = 640077562, doorcoords = vector3(1702.7976, 1514.3334, 146.878) },
    { houseid = 'house43', doorid = 3045682143, doorcoords = vector3(-3400.0259, -3302.1235, -5.3949) },
    { houseid = 'house44', doorid = 1915887592, doorcoords = vector3(-818.6138, 351.1617, 97.1088) },
    { houseid = 'house44', doorid = 3324299212, doorcoords = vector3(-819.1437, 358.7344, 97.1063) },
    { houseid = 'house45', doorid = 1180868565, doorcoords = vector3(2711.437, -1293.0839, 59.4585) },
    { houseid = 'house46', doorid = 1535511805, doorcoords = vector3(-2590.8411, 457.838, 146.014) },
    { houseid = 'house46', doorid = 2395304827, doorcoords = vector3(-2597.7019, 457.8384, 146.014) },
    { houseid = 'house47', doorid = 1762076266, doorcoords = vector3(2238.11, -141.63, 47.6) },
    { houseid = 'house47', doorid = 2689340659, doorcoords = vector3(2234.82, -146.91, 47.64) },
    { houseid = 'house48', doorid = 1606546482, doorcoords = vector3(-1645.98, -1367.7, 84.52) },
    { houseid = 'house48', doorid = 818583340, doorcoords = vector3(-1649.01, -1358.55, 84.46) },
    { houseid = 'house48', doorid = 2310818050, doorcoords = vector3(-1636.94, -1352.22, 83.97) },
    { houseid = 'house49', doorid = 362914435, doorcoords = vector3(2311.32, -328.13, 41.9) },
    { houseid = 'house49', doorid = 3108731901, doorcoords = vector3(2307.65, -332.63, 41.9) },
    { houseid = 'house50', doorid = 3929468747, doorcoords = vector3(1136.31, -977.52, 69.39) },
    { houseid = 'house51', doorid = 4123766266, doorcoords = vector3(778.2, 849.15, 118.93) },
    { houseid = 'house51', doorid = 417362979, doorcoords = vector3(772.95, 842.26, 118.92) },
}
