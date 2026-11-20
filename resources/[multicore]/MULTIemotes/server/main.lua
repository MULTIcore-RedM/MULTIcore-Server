-- ============================================================
-- MULTIemotes :: server (walk styles)
-- The walk style is checked here, saved in the character's metadata
-- (Config.WalkMetadataKey, the same key RSG v2 rsg-radialmenu uses)
-- and shared through the player's state bag so every client can put
-- it on that player's ped. Emotes themselves are client only.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local KEY = Config.WalkMetadataKey
local lastChange = {}

local function dbg(...) if Config.Debug then print('[MULTIemotes]', ...) end end

local function setState(src, id)
    -- state bags only exist for connected players; pretend players in tests have none
    pcall(function() Player(src).state:set(KEY, id, true) end)
end

local function validId(id)
    return type(id) == 'string' and MEM.WalkById[id] ~= nil
end

--- The character's saved walk style id, or nil.
local function getWalk(src)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return nil end
    local id = P.PlayerData.metadata and P.PlayerData.metadata[KEY]
    return validId(id) and id or nil
end

--- Sets (id) or clears (nil / false) the walk style of `src`, no cooldown. -> true | false, locale key
local function setWalk(src, id)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false, 'err_not_loaded' end
    if id == false or id == '' then id = nil end
    if id ~= nil and not validId(id) then return false, 'err_walk_unknown' end
    P.Functions.SetMetaData(KEY, id)
    setState(src, id)
    dbg(('walk style of %s: %s'):format(src, tostring(id)))
    return true
end

--- The player's own request (menu, /walk): adds the cooldown.
local function request(src, id)
    local now = GetGameTimer()
    if lastChange[src] and now - lastChange[src] < Config.WalkCooldown * 1000 then return false, 'err_cooldown' end
    local ok, err = setWalk(src, id)
    if ok then lastChange[src] = now end
    return ok, err
end

lib.callback.register('MULTIemotes:setWalk', function(src, id)
    if id ~= false and type(id) ~= 'string' then return false, 'err_walk_unknown' end
    return request(src, id)
end)

-- put the saved style back on when a character loads
AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    if not P or not P.PlayerData then return end
    local id = P.PlayerData.metadata and P.PlayerData.metadata[KEY]
    setState(P.PlayerData.source, validId(id) and id or nil)
end)

-- and for everyone online after a restart of this resource
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        setState(src, getWalk(src))
    end
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    lastChange[src] = nil
    setState(src, nil)
end)
AddEventHandler('playerDropped', function() lastChange[source] = nil end)

---------------------------------
-- exports
---------------------------------
exports('GetWalkstyle', getWalk)
exports('SetWalkstyle', setWalk)
exports('GetWalkstyles', function()
    local out = {}
    for _, w in ipairs(Config.Walkstyles) do out[#out + 1] = w.id end
    return out
end)
exports('GetEmotes', function()
    local out = {}
    for _, e in ipairs(Config.Emotes) do
        if e.kind then out[#out + 1] = { id = e.id, cat = e.cat, kind = e.kind } end
    end
    return out
end)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true)
---------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestRequest', request)
    exports('_TestResetCooldown', function(src) lastChange[src] = nil end)
    exports('_TestLocales', function()
        -- every shipped language must have the same keys as English
        local missing = {}
        for code, t in pairs(Locales) do
            for k in pairs(Locales.en) do
                if t[k] == nil then missing[#missing + 1] = code .. ':' .. k end
            end
            for k in pairs(t) do
                if Locales.en[k] == nil then missing[#missing + 1] = code .. ':+' .. k end
            end
        end
        local langs = {}
        for code in pairs(Locales) do langs[#langs + 1] = code end
        return missing, langs
    end)
    exports('_TestFind', function(text, kind)
        local e = kind == 'walk' and MEM.FindWalk(text) or MEM.FindEmote(text)
        return e and e.id or nil
    end)
end
