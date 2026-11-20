--[[
    Worn clothing items <-> MULTIcore look (server).

    MULTIinventory's equipment slots are what a character wears; MULTIcore's look (multicore_appearance,
    exports.MULTIcore:GetLook / SaveLook) is what every MULTI script shows and re-applies (spawn,
    respawn, character select, barber). This file keeps the two in step:

    1. Mirror: after every clothing change (MULTIinventory:clothingChanged, debounced Config.Look.debounceMs)
       the worn pieces are written into the look's comps (hash -> MULTIData index, TLook.toComps).
       Categories the equipment slots do not manage (hair, body pieces ...) are kept as they are.
    2. First load: a character with no clothing items but clothes in their look gets those clothes as
       items in their equipment slots, once (a piece that cannot go into its slot lands in the satchel).
       Done when multitailor_meta holds 'seed:<citizenid>'. Until then nothing is mirrored, so a look
       is never emptied before its clothes became items.
    The client side (client/90_look.lua) puts the worn items back on after MULTIcore applied the look.

    Server-local event after a mirror: MULTItailor:lookMirrored (src, comps)
    Exports: MirrorLook(src) -> bool   SeedClothing(src) -> bool (runs the first-load check now)
]]
TLookS = TLookS or {}

local INV = 'MULTIinventory'
local charOf, srcOf = {}, {}      -- [src] = charId, [charId] = src
local seeded = {}                 -- [citizenid] = true
local pending = {}                -- [charId] = true while a mirror is scheduled
local seeding = {}                -- [src] = true while the first-load check runs

local function LC() return Config.Look or {} end
local function invUp() return GetResourceState(INV) == 'started' end

local rsg
local function core()
    if not rsg then rsg = exports['rsg-core']:GetCoreObject() end
    return rsg
end
AddEventHandler('RSGCore:Server:UpdateObject', function() rsg = nil end)

local function player(src)
    local ok, P = pcall(function() return core().Functions.GetPlayer(tonumber(src)) end)
    return ok and P or nil
end

local function citizenOf(src)
    local P = player(src)
    return P and P.PlayerData and P.PlayerData.citizenid or nil
end

local function lookOf(citizenid)
    local ok, look = pcall(function() return exports.MULTIcore:GetLook(citizenid) end)
    if not ok or type(look) ~= 'table' then return nil end
    look.skin = type(look.skin) == 'table' and look.skin or {}
    look.comps = type(look.comps) == 'table' and look.comps or {}
    return look
end

local function sexOf(src, look)
    local s = look and look.skin and look.skin.sex
    if s == 'male' or s == 'female' then return s end
    return TA.sex(src) or 'male'
end

---MULTIinventory's character id for a player (nil until the inventory has loaded the character)
local function charIdOf(src)
    if not invUp() then return nil end
    local ok, id = pcall(function() return exports[INV]:GetCharId(src) end)
    id = ok and tonumber(id) or nil
    if id then
        if charOf[src] and charOf[src] ~= id then srcOf[charOf[src]] = nil end
        charOf[src], srcOf[id] = id, src
    end
    return id
end

local function wornOf(charId)
    local ok, worn = pcall(function() return exports[INV]:GetWorn(charId) end)
    if not ok or type(worn) ~= 'table' then return nil end
    return worn
end

local function isSeeded(citizenid)
    if seeded[citizenid] then return true end
    TDB.ready()
    if TDB.meta('seed:' .. citizenid) then seeded[citizenid] = true return true end
    return false
end

local function markSeeded(citizenid)
    if seeded[citizenid] then return end
    seeded[citizenid] = true
    TDB.setMeta('seed:' .. citizenid, os.time())
end

-- ---------------------------------------------------------------- 1. mirror
function TLookS.mirror(src)
    if LC().mirror == false or not invUp() then return false end
    local citizenid = citizenOf(src)
    local charId = charIdOf(src)
    if not citizenid or not charId or not isSeeded(citizenid) then return false end
    local worn = wornOf(charId)
    if not worn then return false end
    local look = lookOf(citizenid)
    if not look then return false end   -- no look yet (character not created): nothing to write into
    local sex = sexOf(src, look)
    local wornComps, skipped = TLook.toComps(worn, sex)
    if #skipped > 0 then TU.debug('look mirror %s: no look index for %s', citizenid, table.concat(skipped, ', ')) end
    local comps = TLook.merge(look.comps, wornComps)
    if TLook.same(comps, look.comps) then return true end
    local ok, saved = pcall(function() return exports.MULTIcore:SaveLook(src, 'comps', comps) end)
    if not ok or not saved then
        print(('^3[MULTItailor] could not save the look of %s^0'):format(citizenid))
        return false
    end
    TriggerEvent('MULTItailor:lookMirrored', src, comps)
    return true
end

local function schedule(charId)
    charId = tonumber(charId)
    if not charId or pending[charId] then return end
    pending[charId] = true
    SetTimeout(math.max(0, tonumber(LC().debounceMs) or 800), function()
        pending[charId] = nil
        local src = srcOf[charId]
        if not src then
            -- not seen yet: find the player whose inventory character this is
            for _, s in ipairs(TA.players()) do
                if charIdOf(s) == charId then src = s break end
            end
        end
        if not src or not player(src) then return end
        local ok, err = pcall(TLookS.mirror, src)
        if not ok then print(('^1[MULTItailor] look mirror failed: %s^0'):format(tostring(err))) end
    end)
end

-- one event per changed slot; batched by schedule()
AddEventHandler('MULTIinventory:clothingChanged', function(charId) schedule(charId) end)

-- ---------------------------------------------------------------- 2. first load
local function giveSpec(src, charId, spec)
    local ok, a = pcall(function() return exports[INV]:CreateClothingItem('equip:' .. charId, spec, 1) end)
    if ok and a then return 'worn' end
    ok, a = pcall(function() return exports[INV]:CreateClothingItem(src, spec, 1) end)
    if ok and a then return 'satchel' end
    return nil
end

function TLookS.seed(src)
    local citizenid = citizenOf(src)
    if not citizenid or not invUp() then return false end
    if isSeeded(citizenid) then return true end
    local charId = charIdOf(src)
    if not charId then return false end
    local worn = wornOf(charId)
    if not worn then return false end
    if next(worn) ~= nil then markSeeded(citizenid) return true end   -- already wears clothing items
    local look = lookOf(citizenid)
    if not look then return false end   -- creator not finished: look again on the next load
    if LC().importOnFirstLoad == false then markSeeded(citizenid) return true end
    local specs = TLook.fromComps(look.comps, sexOf(src, look))
    local worn_n, bag_n, lost = 0, 0, 0
    for _, spec in ipairs(specs) do
        local where = giveSpec(src, charId, spec)
        if where == 'worn' then worn_n = worn_n + 1
        elseif where == 'satchel' then bag_n = bag_n + 1
        else lost = lost + 1 end
    end
    markSeeded(citizenid)
    if #specs > 0 then
        print(('[MULTItailor] %s: %d piece(s) of the saved look became clothing items (%d worn, %d in the satchel%s)')
            :format(citizenid, worn_n + bag_n, worn_n, bag_n, lost > 0 and (', ^3' .. lost .. ' not created^0') or ''))
    end
    return true
end

local function seedLater(src)
    src = tonumber(src)
    if not src or seeding[src] or LC().mirror == false then return end
    seeding[src] = true
    CreateThread(function()
        -- wait for the inventory to load the character
        local deadline = GetGameTimer() + 60000
        while GetGameTimer() < deadline and player(src) and not charIdOf(src) do Wait(500) end
        Wait(math.max(0, tonumber(LC().importDelayMs) or 4000))
        if player(src) then
            local ok, err = pcall(TLookS.seed, src)
            if not ok then print(('^1[MULTItailor] first-load clothing check failed: %s^0'):format(tostring(err))) end
            -- bring the look in step with what is worn now
            pcall(TLookS.mirror, src)
        end
        seeding[src] = nil
    end)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = type(P) == 'table' and P.PlayerData and P.PlayerData.source or source
    seedLater(src)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local id = charOf[src]
    if id then srcOf[id] = nil end
    charOf[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = charOf[src]
    if id then srcOf[id] = nil end
    charOf[src], seeding[src] = nil, nil
end)

-- a deleted character's flag goes with it
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    seeded[citizenid] = nil
    TDB.ready()
    MySQL.update('DELETE FROM `multitailor_meta` WHERE k = ?', { 'seed:' .. citizenid })
end)

-- players already in the world when MULTItailor (re)starts
CreateThread(function()
    Wait(5000)
    for _, src in ipairs(TA.players()) do
        if player(src) then seedLater(src) end
    end
end)

exports('MirrorLook', function(src) return TLookS.mirror(tonumber(src)) end)
exports('SeedClothing', function(src) return TLookS.seed(tonumber(src)) end)
