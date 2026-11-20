-- ============================================================
-- MULTIhorses :: horses for sale
-- Models checked against femga peds_list.lua. Prices are RDR2's stable
-- prices (1899), cents allowed. A stable buys a horse back for
-- Config.SellBack of its price (never more than half).
--
-- model:   ped model
-- breed:   locale key part (breed_<breed>)
-- coat:    locale key part (coat_<coat>)
-- price:   dollars
-- stables: optional list of stable ids that sell it (nil = every stable)
-- ============================================================

Config.Horses = {
    -- light riding horses
    { model = 'a_c_horse_kentuckysaddle_black',               breed = 'kentuckysaddle',  coat = 'black',            price = 50.00 },
    { model = 'a_c_horse_kentuckysaddle_silverbay',           breed = 'kentuckysaddle',  coat = 'silverbay',        price = 50.00 },
    { model = 'a_c_horse_kentuckysaddle_chestnutpinto',       breed = 'kentuckysaddle',  coat = 'chestnutpinto',    price = 50.00 },
    { model = 'a_c_horse_kentuckysaddle_grey',                breed = 'kentuckysaddle',  coat = 'grey',             price = 50.00 },
    { model = 'a_c_horse_morgan_bay',                         breed = 'morgan',          coat = 'bay',              price = 55.00 },
    { model = 'a_c_horse_morgan_bayroan',                     breed = 'morgan',          coat = 'bayroan',          price = 55.00 },
    { model = 'a_c_horse_morgan_flaxenchestnut',              breed = 'morgan',          coat = 'flaxenchestnut',   price = 55.00 },
    { model = 'a_c_horse_morgan_palomino',                    breed = 'morgan',          coat = 'palomino',         price = 55.00 },
    { model = 'a_c_horse_tennesseewalker_chestnut',           breed = 'tennesseewalker', coat = 'chestnut',         price = 60.00 },
    { model = 'a_c_horse_tennesseewalker_dapplebay',          breed = 'tennesseewalker', coat = 'dapplebay',        price = 60.00 },
    { model = 'a_c_horse_tennesseewalker_redroan',            breed = 'tennesseewalker', coat = 'redroan',          price = 60.00 },
    -- work horses
    { model = 'a_c_horse_belgian_blondchestnut',              breed = 'belgian',         coat = 'blondchestnut',    price = 120.00 },
    { model = 'a_c_horse_suffolkpunch_sorrel',                breed = 'suffolkpunch',    coat = 'sorrel',           price = 120.00 },
    { model = 'a_c_horse_shire_darkbay',                      breed = 'shire',           coat = 'darkbay',          price = 120.00 },
    { model = 'a_c_horse_shire_ravenblack',                   breed = 'shire',           coat = 'ravenblack',       price = 130.00 },
    -- all-round horses
    { model = 'a_c_horse_americanstandardbred_black',         breed = 'standardbred',    coat = 'black',            price = 130.00 },
    { model = 'a_c_horse_americanstandardbred_buckskin',      breed = 'standardbred',    coat = 'buckskin',         price = 130.00 },
    { model = 'a_c_horse_americanstandardbred_palominodapple', breed = 'standardbred',   coat = 'palominodapple',   price = 150.00 },
    { model = 'a_c_horse_hungarianhalfbred_darkdapplegrey',   breed = 'hungarian',       coat = 'darkdapplegrey',   price = 130.00 },
    { model = 'a_c_horse_hungarianhalfbred_flaxenchestnut',   breed = 'hungarian',       coat = 'flaxenchestnut',   price = 130.00 },
    { model = 'a_c_horse_nokota_blueroan',                    breed = 'nokota',          coat = 'blueroan',         price = 130.00 },
    { model = 'a_c_horse_nokota_reversedappleroan',           breed = 'nokota',          coat = 'reversedappleroan', price = 135.00 },
    -- Mustang and Appaloosa: no story-mode stable price to copy (these coats are caught wild in
    -- RDR2); priced with the other mid-range breeds (Nokota 130-135, Paint 140). Every other
    -- price in this list matches RDR2's story-mode stables.
    { model = 'a_c_horse_mustang_grullodun',                  breed = 'mustang',         coat = 'grullodun',        price = 130.00 },
    { model = 'a_c_horse_mustang_wildbay',                    breed = 'mustang',         coat = 'wildbay',          price = 130.00 },
    { model = 'a_c_horse_americanpaint_overo',                breed = 'paint',           coat = 'overo',            price = 140.00 },
    { model = 'a_c_horse_americanpaint_tobiano',              breed = 'paint',           coat = 'tobiano',          price = 140.00 },
    { model = 'a_c_horse_appaloosa_blanket',                  breed = 'appaloosa',       coat = 'blanket',          price = 150.00 },
    { model = 'a_c_horse_appaloosa_leopard',                  breed = 'appaloosa',       coat = 'leopard',          price = 160.00 },
    -- fine horses
    { model = 'a_c_horse_thoroughbred_bloodbay',              breed = 'thoroughbred',    coat = 'bloodbay',         price = 450.00 },
    { model = 'a_c_horse_thoroughbred_dapplegrey',            breed = 'thoroughbred',    coat = 'dapplegrey',       price = 450.00 },
    { model = 'a_c_horse_thoroughbred_blackchestnut',         breed = 'thoroughbred',    coat = 'blackchestnut',    price = 550.00 },
    { model = 'a_c_horse_dutchwarmblood_chocolateroan',       breed = 'dutchwarmblood',  coat = 'chocolateroan',    price = 450.00 },
    { model = 'a_c_horse_dutchwarmblood_sealbrown',           breed = 'dutchwarmblood',  coat = 'sealbrown',        price = 450.00 },
    { model = 'a_c_horse_dutchwarmblood_sootybuckskin',       breed = 'dutchwarmblood',  coat = 'sootybuckskin',    price = 950.00 },
    { model = 'a_c_horse_missourifoxtrotter_amberchampagne',  breed = 'foxtrotter',      coat = 'amberchampagne',   price = 950.00 },
    { model = 'a_c_horse_missourifoxtrotter_silverdapplepinto', breed = 'foxtrotter',    coat = 'silverdapplepinto', price = 950.00 },
    { model = 'a_c_horse_turkoman_gold',                      breed = 'turkoman',        coat = 'gold',             price = 925.00, stables = { 'saintdenis', 'blackwater' } },
    { model = 'a_c_horse_turkoman_silver',                    breed = 'turkoman',        coat = 'silver',           price = 950.00, stables = { 'saintdenis', 'blackwater' } },
    { model = 'a_c_horse_arabian_rosegreybay',                breed = 'arabian',         coat = 'rosegreybay',      price = 1050.00, stables = { 'saintdenis' } },
    { model = 'a_c_horse_arabian_redchestnut',                breed = 'arabian',         coat = 'redchestnut',      price = 1050.00, stables = { 'saintdenis' } },
    { model = 'a_c_horse_arabian_white',                      breed = 'arabian',         coat = 'white',            price = 1250.00, stables = { 'saintdenis' } },
}

-- Price of a horse not in the list above (a starter horse made by another script, an old rsg-horses horse).
-- Selling it pays Config.SellBack of this.
Config.UnlistedPrice = 20.00        -- default 20.00
