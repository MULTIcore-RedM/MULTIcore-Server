-- ============================================================
-- MULTIwagons: wagons the dealers sell
-- Model names are RSG v2 rsg-wagons' working names, each checked in
-- redm-info objects.lua and femga object_list.lua.
-- Prices: late-1890s mail-order catalogue level (road carts $10 - $25,
-- buggies $30 - $90, farm and spring wagons $40 - $80, freight and
-- delivery wagons $100 - $175, closed carriages $250 and up).
--   model     game model name (also the locale key 'wagon_<model>' for its label)
--   category  'cart' | 'buggy' | 'wagon' | 'coach' (locale key 'cat_<category>')
--   price     dollars with cents
--   slots     storage slots
--   weight    storage weight in kg
--   enabled   false = not sold (owned ones keep working)
-- Order here is the order in the dealer menu.
-- ============================================================

Config.Categories = { 'cart', 'buggy', 'wagon', 'coach' }   -- order of the dealer's categories

Config.Wagons = {
    -- carts
    { model = 'cart03',            category = 'cart',  price = 18.00,  slots = 10, weight = 150 },
    { model = 'cart01',            category = 'cart',  price = 20.00,  slots = 12, weight = 180 },
    { model = 'cart02',            category = 'cart',  price = 24.00,  slots = 14, weight = 200 },
    { model = 'cart04',            category = 'cart',  price = 26.00,  slots = 14, weight = 200 },
    { model = 'cart07',            category = 'cart',  price = 28.00,  slots = 15, weight = 220 },
    { model = 'cart08',            category = 'cart',  price = 30.00,  slots = 16, weight = 240 },
    -- buggies
    { model = 'buggy02',           category = 'buggy', price = 45.00,  slots = 6,  weight = 60 },
    { model = 'buggy01',           category = 'buggy', price = 70.00,  slots = 8,  weight = 80 },
    { model = 'buggy03',           category = 'buggy', price = 85.00,  slots = 10, weight = 100 },
    -- wagons
    { model = 'utilliwag',         category = 'wagon', price = 40.00,  slots = 18, weight = 300 },
    { model = 'wagon04x',          category = 'wagon', price = 55.00,  slots = 20, weight = 350 },
    { model = 'wagon05x',          category = 'wagon', price = 60.00,  slots = 20, weight = 380 },
    { model = 'wagon02x',          category = 'wagon', price = 65.00,  slots = 22, weight = 400 },
    { model = 'wagon03x',          category = 'wagon', price = 70.00,  slots = 22, weight = 420 },
    { model = 'wagon06x',          category = 'wagon', price = 80.00,  slots = 25, weight = 450 },
    { model = 'huntercart01',      category = 'wagon', price = 95.00,  slots = 20, weight = 300 },
    { model = 'chuckwagon000x',    category = 'wagon', price = 120.00, slots = 28, weight = 500 },
    { model = 'wagontraveller01x', category = 'wagon', price = 150.00, slots = 30, weight = 500 },
    { model = 'supplywagon',       category = 'wagon', price = 175.00, slots = 35, weight = 650 },
    -- carriages
    { model = 'coach2',            category = 'coach', price = 300.00, slots = 10, weight = 120 },
}
