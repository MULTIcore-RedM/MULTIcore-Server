--[[
    Client side of old `tailored_outfit` items: nothing is worn from them any more (the server turns
    them into MULTIinventory clothing items, server/60_wear.lua). Only the export stays.
]]
exports('GetOutfitComponents', function(metadata) return TS.components(metadata) end)
