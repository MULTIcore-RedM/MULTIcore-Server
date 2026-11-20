--[[
    Old `tailored_outfit` items (an outfit or one garment carried as a single item, from before
    clothing became inventory items). Using one turns it into MULTIinventory clothing:
      * an outfit          -> one `clothing_outfit` bundle (use it to unpack the pieces)
      * a single garment   -> that garment as a clothing item (clothing_hat, clothing_shirt ...)
    The old item is taken first and given back if the new one does not fit.
    New garments are always clothing items (TA.givePiece / TA.giveOutfit), so on a fresh server
    no `tailored_outfit` ever exists.
]]
local lastUse = {}

local function convert(src, it)
    local meta = it.metadata or it.info or {}
    local outfit = TS.components(meta)
    if not outfit then return false, L('err_not_outfit') end
    local sex = TA.sex(src)
    if sex and sex ~= outfit.sex then
        return false, L('err_wrong_sex', ((Config.Designer.sexLabels or {})[outfit.sex] or outfit.sex):lower())
    end
    if TA.clothingFormat() ~= 'multi' then return false, L('err_inventory_missing') end

    local item = Config.Items.outfitItem
    local taken
    if it.id ~= nil then taken = TA.removeById(src, it.id, 1) else taken = TA.remove(src, item, 1) end
    if not taken then return false, L('err_generic') end

    local ok, err
    if outfit.single and #outfit.pieces == 1 then
        local p = outfit.pieces[1]
        ok, err = TA.givePiece(src, {
            cat = p.category, hash = p.hash, sex = outfit.sex, m = p.model, v = p.variant,
            label = outfit.name, description = meta.description,
            palette = p.palette, tints = { p.tint0, p.tint1, p.tint2 },
        })
    else
        local pieces = {}
        for _, p in ipairs(meta.pieces) do
            if type(p) == 'table' and TS.category(p.c) and tonumber(p.h) then
                pieces[#pieces + 1] = { c = p.c, h = tonumber(p.h), m = p.m, v = p.v, p = tonumber(p.p) or 0,
                                        t = type(p.t) == 'table' and p.t or { 0, 0, 0 } }
            end
        end
        ok, err = TA.giveOutfit(src, {
            name = TU.text(outfit.name, 50) or L('title'), description = TU.text(meta.description, 255),
            sex = outfit.sex, pieces = pieces, meta = meta,
        })
    end
    if ok then return true end
    TA.give(src, item, 1, meta)   -- put the old item back
    TU.debug('tailored_outfit conversion failed: %s', tostring(err))
    return false, (err == 'inventory_missing') and L('err_inventory_missing') or L('err_no_room')
end

local function onUse(data)
    local src = data and data.source
    if not src then return end
    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < 3000 then return TA.notify(src, L('err_wear_busy'), 'error') end
    lastUse[src] = now
    local it = data.item or {}
    local ok, err = convert(src, it)
    if not ok then return TA.notify(src, err or L('err_wear_failed'), 'error') end
    TA.notify(src, L('outfit_converted'), 'success')
    local meta = it.metadata or it.info or {}
    TriggerEvent('MULTItailor:outfitWorn', src, { uid = meta.uid, name = meta.outfit or meta.label, converted = true })
end

CreateThread(function()
    if MBridge.WaitForFramework then pcall(MBridge.WaitForFramework, 60000) end
    Wait(2000)
    if MBridge.IsRsg and MBridge.RegisterItems then pcall(MBridge.RegisterItems) end
    if MBridge.IsRsg then pcall(TA.ensureRsgJobs) end
    TA.registerUsable(Config.Items.outfitItem, onUse)
    local cat, cerr = TS.catalogue()
    print(('[MULTItailor] tailoring ready: %s, %d catalogue categories, items: %s%s'):format(TS.appearance(), TS.categoryCount(),
        TA.clothingFormat(), cat and '' or (' ^1(catalogue: ' .. tostring(cerr) .. ')^0')))
end)

AddEventHandler('playerDropped', function() lastUse[source] = nil end)

---exports.MULTItailor:WearOutfit(src, metadata): garments are inventory items now, so nothing is put on
---from bare metadata and false is returned. Hand a garment over with CreateGarment, or wear owned pieces
---with MULTIinventory's clothing exports.
function TWear() return false end
