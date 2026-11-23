-- ============================================================
-- MULTIhotel settings
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- Every line a player sees is in locales/<lang>.lua.
-- ============================================================
Config = {}

Config.Locale = ''                  -- default '' (language for this script; empty = MULTIcore's language (MULTIConfig.Language), else English)
Config.Debug  = false               -- default false (extra prints in F8 / the server console)

---------------------------------
-- money and rent
---------------------------------
Config.Currency      = 'cash'       -- default 'cash' (money type players pay with and get back)
Config.StartCredit   = 10           -- default 10 (paid when renting; it becomes the room's first credit)
Config.RentPerCycle  = 1            -- default 1 (credit taken from every room each billing cycle)
Config.BillingCycle  = 1            -- default 1 (hours between two billing cycles)
Config.CreditWarning = 5            -- default 5 (a warning telegram goes out when credit < RentPerCycle x this)
Config.MaxCredit     = 10000        -- default 10000 (most credit one room may hold)

---------------------------------
-- room locker (MULTIinventory)
---------------------------------
Config.StorageMaxWeight = 4000000   -- default 4000000 (grams; MULTIinventory counts weight in grams, so 4000 kg)
Config.StorageMaxSlots  = 48        -- default 48 (slots in a room locker)
Config.PurgeStorage     = false     -- default false (true = the locker is emptied when a room is lost for unpaid rent)

---------------------------------
-- guests
---------------------------------
Config.MaxGuests              = 5     -- default 5 (guests one room may have)
Config.InviteDistance         = 15.0  -- default 15.0 (metres: only players this close to the owner can be invited, e.g. down in the lobby)
Config.EvictionCooldown       = 300   -- default 300 (seconds before the owner may throw guests out again)
Config.RemoveGuestsOnEviction = false -- default false (true = thrown-out guests also lose their invitation)

---------------------------------
-- rooms
---------------------------------
Config.BucketOffset = 40000         -- default 40000 (room N is routing bucket BucketOffset + N, so rooms never share a bucket with other scripts)
Config.LockDoors    = true          -- default true (keep the hotel doors in Config.HotelDoors locked)

---------------------------------
-- interaction (MULTItarget, hold Left Alt)
---------------------------------
Config.Interact       = 'auto'      -- default 'auto' ('auto' = MULTItarget when it runs, else hold-key prompts; 'target'; 'prompt')
Config.Key            = 'J'         -- default 'J' (prompt key at the desk and in the room; prompt mode only)
Config.TargetRadius   = 1.5         -- default 1.5 (size of the MULTItarget point at the desk and in the room)
Config.TargetDistance = 2.5         -- default 2.5 (how close to stand for MULTItarget)
Config.PromptDistance = 2.0         -- default 2.0 (metres at which a prompt shows; prompt mode)
Config.ServerDistance = 10.0        -- default 10.0 (the server refuses desk actions farther than this from the desk)

---------------------------------
-- blips
---------------------------------
Config.Blip = {
    sprite = 'blip_hotel_bed',      -- default 'blip_hotel_bed'
    scale  = 0.2,                   -- default 0.2
    style  = 1664425300,            -- default 1664425300 (BlipAddForCoords style)
}

---------------------------------
-- logs (MULTIserver)
---------------------------------
Config.LogName = 'hotel'            -- default 'hotel' (MULTIserver log name; '' = no logs)

---------------------------------
-- commands ('' = off)
---------------------------------
Config.Commands = {
    fixNui = 'hotelfix',            -- default 'hotelfix' (closes the hotel page if it ever gets stuck)
}

---------------------------------
-- hotels
-- id     : short name, saved with every room (do not change it once rooms are rented)
-- label  : name players see (a locale key if it starts with 'hotel_')
-- desk   : the front desk point (rent, check in)
-- room   : the room menu point inside the room
-- spawn  : where you stand after checking in (x, y, z, heading)
-- exit   : where you stand after leaving the room (x, y, z, heading)
-- blip   : true = map blip at the desk
---------------------------------
Config.Hotels = {
    {
        id = 'valentine', label = 'hotel_valentine', blip = true,
        desk  = vector3(-325.7658, 774.46496, 117.45713),
        room  = vector3(-323.935, 767.02294, 121.6327),
        spawn = vector4(-323.935, 767.02294, 121.6327, 102.64147),
        exit  = vector4(-328.99, 772.95, 117.45, 13.64),
    },
    {
        id = 'strawberry', label = 'hotel_strawberry', blip = true,
        desk  = vector3(-1817.56, -370.8123, 163.29635),
        room  = vector3(-1813.394, -368.9348, 166.49964),
        spawn = vector4(-1813.903, -370.0737, 166.49919, 269.52258),
        exit  = vector4(-1814.274, -369.9327, 162.88313, 277.07699),
    },
    {
        id = 'rhodes', label = 'hotel_rhodes', blip = true,
        desk  = vector3(1339.4562, -1377.151, 80.48069),
        room  = vector3(1331.4257, -1371.862, 80.490127),
        spawn = vector4(1331.4257, -1371.862, 80.490127, 259.164),
        exit  = vector4(1334.2458, -1368.744, 80.490165, 258.45336),
    },
    {
        id = 'stdenis', label = 'hotel_stdenis', blip = true,
        desk  = vector3(2637.968, -1227.239, 53.380374),
        room  = vector3(2637.925, -1222.1, 59.600513),
        spawn = vector4(2637.925, -1222.1, 59.600513, 179.36787),
        exit  = vector4(2633.2497, -1223.527, 59.594661, 176.20422),
    },
    {
        id = 'blackwater', label = 'hotel_blackwater', blip = true,
        desk  = vector3(-815.73, -1318.86, 43.76),
        room  = vector3(-820.12, -1324.15, 47.97),
        spawn = vector4(-820.16, -1324.35, 47.97, 90.93),
        exit  = vector4(-819.7, -1313.11, 43.77, 248.03),
    },
    {
        id = 'tumbleweed', label = 'hotel_tumbleweed', blip = true,
        desk  = vector3(-5511.62, -2974.64, 2.22),
        room  = vector3(-5513.07, -2971.57, 2.23),
        spawn = vector4(-5513.73, -2972.29, 2.22, 21.03),
        exit  = vector4(-5518.85, -2976.54, -0.78, 108.9),
    },
    {
        id = 'annesburg', label = 'hotel_annesburg', blip = true,
        desk  = vector3(2947.66, 1332.55, 44.46),
        room  = vector3(2946.09, 1330.59, 44.46),
        spawn = vector4(2946.09, 1330.59, 44.46, 167.87),
        exit  = vector4(2946.28, 1333.36, 44.45, 55.87),
    },
}

-- door hashes kept locked when Config.LockDoors is on
Config.HotelDoors = {
    238680582,  -- valentine
    3765902977, -- valentine
    3049177115, -- valentine
    1407130373, -- strawberry
    1654175864, -- strawberry
    2046695029, -- rhodes
    1555588463, -- saint denis
    2693793043, -- saint denis
    2999855503, -- saint denis
    1275780106, -- saint denis
    3461406868, -- saint denis
    254520182,  -- blackwater
    2959320055, -- tumbleweed
    1335986638, -- annesburg
}
