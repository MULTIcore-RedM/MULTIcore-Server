--[[
    Wardrobe (server): saved outfits and rsg-wardrobe's server API.

    Saved outfits live in MULTIinventory (GetOutfits / SaveOutfit / WearOutfit / DeleteOutfit / RenameOutfit):
    an outfit is a list of the clothing items worn when it was saved; wearing it puts on the pieces the
    player still owns. Wearing is allowed at a clothes store clerk, at a wardrobe point, or anywhere when
    Config.Outfits.command is set.

    lib.callback:
      multitailor:outfits:list   ()          -> { { id, name, pieces = n } }
      multitailor:outfits:save   (name)      -> ok, err
      multitailor:outfits:rename (id, name)  -> ok, err
      multitailor:outfits:delete (id)        -> ok, err
      multitailor:outfits:wear   (id)        -> ok, { equipped, missing, failed } | err

    rsg-wardrobe server exports (MULTItailor answers as rsg-wardrobe; names and arguments as RSG v2's):
      exports['rsg-wardrobe']:TogglePlayerClothing(source, name)
      exports['rsg-wardrobe']:RemovePlayerClothing(source)
      exports['rsg-wardrobe']:DressPlayer(source)
    MULTItailor export: OpenOutfits(source) -> opens the outfit list for that player
]]
local INV = 'MULTIinventory'

local function inv(fn, ...)
    if GetResourceState(INV) ~= 'started' then return false, 'inventory_missing' end
    local ok, a, b = pcall(function(...) return exports[INV][fn](exports[INV], ...) end, ...)
    if not ok then
        TU.debug('%s failed: %s', fn, tostring(a))
        return false, 'inventory_error'
    end
    return a, b
end

local function cleanName(s)
    return TU.text(s, tonumber((Config.Outfits or {}).nameMax) or 40)
end

local function nearWardrobe(src)
    local cmd = (Config.Outfits or {}).command
    if type(cmd) == 'string' and cmd ~= '' then return true end
    local w = Config.Wardrobes or {}
    if w.enabled ~= false then
        for _, p in ipairs(w.points or {}) do
            if TA.dist(src, p) <= (tonumber(w.serverDistance) or 4.0) then return true end
        end
    end
    if (Config.Stores or {}).outfitsAtClerk ~= false then
        for _, s in ipairs(TStores.all() or {}) do
            if s.clerk and s.enabled ~= false and not s.deleted
                and TA.dist(src, s.clerk) <= ((Config.Stores or {}).serverDistance or 6.0) then
                return true
            end
        end
    end
    return false
end

lib.callback.register('multitailor:outfits:list', function(src)
    local list = inv('GetOutfits', src)
    local out = {}
    for _, o in ipairs(type(list) == 'table' and list or {}) do
        out[#out + 1] = { id = o.id, name = o.name, pieces = type(o.pieces) == 'table' and #o.pieces or 0 }
    end
    table.sort(out, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    return out
end)

lib.callback.register('multitailor:outfits:save', function(src, name)
    if not TA.rate(src, 'outfit') then return false, 'slow' end
    name = cleanName(name)
    if not name then return false, 'bad_name' end
    return inv('SaveOutfit', src, name)
end)

lib.callback.register('multitailor:outfits:rename', function(src, id, name)
    if not TA.rate(src, 'outfit') then return false, 'slow' end
    name = cleanName(name)
    if not name or not tonumber(id) then return false, 'bad_name' end
    return inv('RenameOutfit', src, tonumber(id), name)
end)

lib.callback.register('multitailor:outfits:delete', function(src, id)
    if not TA.rate(src, 'outfit') then return false, 'slow' end
    if not tonumber(id) then return false, 'no_outfit' end
    return inv('DeleteOutfit', src, tonumber(id))
end)

lib.callback.register('multitailor:outfits:wear', function(src, id)
    if not TA.rate(src, 'outfit') then return false, 'slow' end
    if not tonumber(id) then return false, 'no_outfit' end
    if not nearWardrobe(src) then return false, 'too_far' end
    local ok, res = inv('WearOutfit', src, tonumber(id), (Config.Outfits or {}).undress == true)
    if not ok then return false, res end
    res = type(res) == 'table' and res or {}
    local failed = 0
    for _ in pairs(res.failed or {}) do failed = failed + 1 end
    return true, { equipped = tonumber(res.equipped) or 0, missing = #(res.missing or {}), failed = failed }
end)

exports('OpenOutfits', function(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    TriggerClientEvent('MULTItailor:client:openOutfits', src, {})
    return true
end)

-- ---------------------------------------------------------------- rsg-wardrobe server API
local function wardrobeExport(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_rsg-wardrobe_%s'):format(name), function(setCB) setCB(fn) end)
end

wardrobeExport('TogglePlayerClothing', function(source, name)
    if not tonumber(source) then return end
    TriggerClientEvent('rsg-wardrobe:client:OnOffClothing', tonumber(source), name)
end)

wardrobeExport('RemovePlayerClothing', function(source)
    if not tonumber(source) then return end
    TriggerClientEvent('rsg-wardrobe:client:removeAllClothing', tonumber(source))
end)

wardrobeExport('DressPlayer', function(source)
    if not tonumber(source) then return end
    TriggerClientEvent('MULTItailor:client:dress', tonumber(source))
end)
