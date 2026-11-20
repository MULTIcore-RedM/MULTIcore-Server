--[[
    Exports + admin command.

    Server exports (exports.MULTItailor:<Name>):
      GetOutfitComponents(metadata)        -> normalised outfit | nil   (tailored_outfit metadata)
      IsTailoredOutfit(itemName)           -> boolean
      GetTailoringCategories()             -> { { id, label, vorp, tag, group, keep } }
      WearOutfit(src, metadata)            -> boolean   (same flow as using the item; the item is never consumed)
      GetClothesStores()                   -> { { id, label, town, clerk, enabled, ... } }
      GetStoreCatalogue()                  -> resolved ready-made lines
      GetTillBalance(businessId)           -> number
      CreateGarment(src, { cat, hash, sex, label, description?, palette?, tints? }) -> ok, err
            hands one garment over in this server's item format (MULTIinventory clothing / tailored_outfit)
      (dynamic-location API: see server/10_points.lua)
    Command: /tailorstores  (admin) - clothes store editor.
]]
exports('GetOutfitComponents', function(metadata) return TS.components(metadata) end)
exports('IsTailoredOutfit', function(itemName) return itemName == Config.Items.outfitItem end)
exports('GetTailoringCategories', function()
    local out = {}
    for _, c in ipairs(Config.Designer.categories) do
        out[#out + 1] = { id = c.id, label = c.label, vorp = c.vorp, tag = c.tag, group = c.group, keep = c.keep == true }
    end
    return out
end)
exports('WearOutfit', function(src, metadata) return TWear(src, metadata) end)
exports('GetClothesStores', function() return TStores.all() end)
exports('GetStoreCatalogue', function() return TU.copy(TStores.lines()) end)
exports('GetTillBalance', function(bid) TDB.ready() return TDB.till.balance(bid) end)
exports('CreateGarment', function(src, piece)
    if type(piece) ~= 'table' or not TS.category(piece.cat) or not TU.finite(piece.hash) or not TS.sexOf(piece.sex) then
        return false, 'bad_piece'
    end
    piece.sex = TS.sexOf(piece.sex)
    return TA.givePiece(tonumber(src), piece)
end)

RegisterCommand('tailorstores', function(src)
    if src == 0 then return print('[MULTItailor] /tailorstores is an in-game command') end
    if not TA.isAdmin(src) then return TA.notify(src, L('err_no_access'), 'error') end
    TriggerClientEvent('MULTItailor:adminMenu', src)
end, false)
