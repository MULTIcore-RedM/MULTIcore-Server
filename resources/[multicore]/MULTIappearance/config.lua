-- ============================================================
-- MULTIappearance :: config
-- Every option has a one-line comment and its default.
-- MULTIappearance shows no text to players, so it has no locales.
-- ============================================================

Config = {}

Config.Debug = false                  -- print every rsg-appearance call that is translated or ignored (F8 / server console)

-- rsg-appearance's own save events (SaveSkin, saveOutfit, saveUseOutfit) let the CLIENT say what the
-- character wears, for free. Only rsg-appearance's own creator and store fired them, and neither runs
-- with MULTIcore (MULTIcreator and MULTItailor do that job), so by default they cannot change clothes.
Config.AllowClientSaves = false       -- true = these events may change the saved clothing (no charge, like RSG)

-- rsg-appearance:server:SetPlayerBucket (client asks to be moved to a routing bucket)
Config.Bucket = {
    AllowRandom = true,               -- allow the "random private bucket" request (used while dressing / creating)
    AllowAny = false,                 -- allow any bucket number a client asks for (false = only 0, the normal world)
    RandomMin = 1000,                 -- lowest random bucket number
    RandomMax = 9999,                 -- highest random bucket number
}

-- Saved outfits (rsg-appearance:server:saveOutfit / DeleteOutfit / getOutfits)
Config.Outfits = {
    UseInventoryOutfits = true,       -- rsg-appearance outfit calls use MULTIinventory's saved outfits (clothing items; only while MULTIinventory runs)
    NameMax = 40,                     -- longest outfit name (keep equal to MULTItailor's Config.Outfits.nameMax)
}

Config.KeepHealthOnApplySkin = true   -- exports['rsg-appearance']:ApplySkin() keeps the ped's health when the model is reloaded
