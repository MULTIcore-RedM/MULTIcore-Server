--[[
    Sharing outfits, tobacco from the clothes menu, and how clothes sit (server).

    Sharing (Config.Share): the giver picks one of their saved outfits and a player next to them. The server
    reads the outfit from the giver's own list (never from the client), keeps one open offer per receiver
    and, when the receiver accepts in time and is still close, adds a copy to the receiver's saved outfits
    through MULTIinventory:ImportOutfit. The copy is a list of garments; wearing it puts on what the
    receiver owns that matches.
      lib.callback multitailor:share:nearby ()                -> { { id, name } }   players within reach
      lib.callback multitailor:share:offer  (outfitId, target) -> ok, err
      net event    MULTItailor:server:shareAnswer (offerId, accepted)
      client event MULTItailor:client:shareOffer (offerId, fromName, outfitName, pieces, seconds)

    Tobacco (Config.Tobacco): the list of configured tobacco items and how many the player carries; using
    one is handed to the item's own script (Consume export), so the effects stay in one place.
      lib.callback multitailor:tobacco:list () -> { { item, label, count } }
      lib.callback multitailor:tobacco:use  (item) -> ok, err

    Styles (Config.Styles): the chosen way each worn piece sits, kept in the character's saved data
    (MULTIcore metadata 'multitailor_styles' = { [slot key] = state hash }).
      lib.callback multitailor:styles:get () -> table
      net event    MULTItailor:server:styles (table)
    GPL v3, part of MULTIcore by RINGO (RINGOscripting).
]]
local INV = 'MULTIinventory'
local META = 'multitailor_styles'

local function started(res) return GetResourceState(res) == 'started' end

-- ---------------------------------------------------------------- sharing
local SH = Config.Share or {}
local offers = {}          -- [receiver src] = { id, from, name, pieces, expires }
local nextOffer = 0

local function near(a, b, dist)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= dist
end

lib.callback.register('multitailor:share:nearby', function(src)
    if SH.enabled == false then return {} end
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src and near(src, id, (tonumber(SH.distance) or 3.0)) and TA.char(id) then
            out[#out + 1] = { id = id, name = L('share_person', id) }
        end
    end
    return out
end)

lib.callback.register('multitailor:share:offer', function(src, outfitId, target)
    if SH.enabled == false then return false, 'share_off' end
    if not TA.rate(src, 'share') then return false, 'slow' end
    target = tonumber(target)
    outfitId = tonumber(outfitId)
    if not target or target == src or not outfitId or not GetPlayerName(target) or not TA.char(target) then return false, 'share_no_player' end
    if not near(src, target, (tonumber(SH.distance) or 3.0) + 1.0) then return false, 'share_too_far' end
    if not started(INV) then return false, 'inventory_missing' end
    local ok, list = pcall(function() return exports[INV]:GetOutfits(src) end)
    local outfit
    for _, o in ipairs(ok and type(list) == 'table' and list or {}) do
        if tonumber(o.id) == outfitId then outfit = o break end
    end
    if not outfit or type(outfit.pieces) ~= 'table' or #outfit.pieces == 0 then return false, 'no_outfit' end
    local open = offers[target]
    if open and open.expires > os.time() then return false, 'share_busy' end

    nextOffer = nextOffer + 1
    local seconds = math.max(5, math.floor(tonumber(SH.answerSeconds) or 30))
    -- only what a copy needs: which slot, which garment, its look (no stack ids from the giver's inventory)
    local pieces = {}
    for _, p in ipairs(outfit.pieces) do
        pieces[#pieces + 1] = { key = p.key, item = p.item, hash = p.hash, label = p.label, look = p.look }
    end
    offers[target] = { id = nextOffer, from = src, name = outfit.name, pieces = pieces, expires = os.time() + seconds }
    TriggerClientEvent('MULTItailor:client:shareOffer', target, nextOffer, TA.name(src), outfit.name, #pieces, seconds)
    return true
end)

RegisterNetEvent('MULTItailor:server:shareAnswer', function(offerId, accepted)
    local src = source
    local o = offers[src]
    if not o or o.id ~= tonumber(offerId) then return end
    offers[src] = nil
    local from = o.from
    if accepted ~= true then
        if GetPlayerName(from) then TA.notify(from, L('share_declined'), 'inform') end
        return
    end
    if os.time() > o.expires then return TA.notify(src, L('share_expired'), 'error') end
    if not GetPlayerName(from) or not near(src, from, (tonumber(SH.distance) or 3.0) + 2.0) then
        return TA.notify(src, L('share_too_far'), 'error')
    end
    local ok, done, err = pcall(function() return exports[INV]:ImportOutfit(src, o.name, o.pieces) end)
    if not ok or not done then
        local e = ok and err or 'generic'
        TA.notify(src, L(e == 'outfit_limit' and 'outfit_full' or 'err_generic'), 'error')
        TA.notify(from, L('share_failed'), 'error')
        return
    end
    TA.notify(src, L('share_received', o.name), 'success')
    TA.notify(from, L('share_given', o.name), 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    offers[src] = nil
    for target, o in pairs(offers) do
        if o.from == src then offers[target] = nil end
    end
end)

-- ---------------------------------------------------------------- tobacco
local TB = Config.Tobacco or {}

local function tobaccoAllowed(item)
    for _, name in ipairs(TB.items or {}) do if name == item then return true end end
    return false
end

lib.callback.register('multitailor:tobacco:list', function(src)
    local out = {}
    if TB.enabled == false then return out end
    for _, item in ipairs(TB.items or {}) do
        out[#out + 1] = { item = item, label = TA.label(item) or item, count = tonumber(TA.count(src, item)) or 0 }
    end
    return out
end)

lib.callback.register('multitailor:tobacco:use', function(src, item)
    if TB.enabled == false then return false, 'tobacco_off' end
    if not TA.rate(src, 'tobacco') then return false, 'slow' end
    if type(item) ~= 'string' or not tobaccoAllowed(item) then return false, 'tobacco_off' end
    local res = TB.resource or 'MULTIconsumables'
    if not started(res) then return false, 'tobacco_off' end
    if (tonumber(TA.count(src, item)) or 0) < 1 then return false, 'tobacco_none' end
    local ok, used, err = pcall(function() return exports[res]:Consume(src, item) end)
    if not ok then return false, 'generic' end
    if used == false then return false, err or 'generic' end
    return true
end)

-- ---------------------------------------------------------------- how clothes sit
local ST = Config.Styles or {}

local function styleKeyAllowed(key)
    for _, k in ipairs(ST.keys or {}) do if k == key then return true end end
    return false
end

lib.callback.register('multitailor:styles:get', function(src)
    if ST.enabled == false or not started('MULTIcore') then return {} end
    local ok, v = pcall(function() return exports.MULTIcore:GetMeta(src, META) end)
    return (ok and type(v) == 'table') and v or {}
end)

RegisterNetEvent('MULTItailor:server:styles', function(styles)
    local src = source
    if ST.enabled == false or not started('MULTIcore') then return end
    if not TA.rate(src, 'style') or type(styles) ~= 'table' then return end
    local clean, n = {}, 0
    for key, hash in pairs(styles) do
        hash = math.tointeger(tonumber(hash))
        if type(key) == 'string' and styleKeyAllowed(key) and hash then
            clean[key] = hash
            n = n + 1
            if n >= 16 then break end
        end
    end
    pcall(function() exports.MULTIcore:SetMeta(src, META, clean) end)
end)
