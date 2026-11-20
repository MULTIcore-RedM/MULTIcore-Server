-- ============================================================
-- MULTIhunting :: server
-- Decides every skinning reward: which animal, which grade, has this carcass
-- paid already, is the player near it, has room, carries the tool.
-- The reward rules (one payout per carcass, a short per-player cooldown, only
-- configured items) follow rsg-hunting's server (RSG v2, GPL v3, see CREDITS.md);
-- the code is MULTIcore's own.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

MH.Skinned = {}      -- [netId] = { model = hash, at = os.time() }
MH.LastReward = {}   -- [src] = GetGameTimer() of the last reward

local function dbg(msg)
    if Config.Debug then print(('[MULTIhunting] %s'):format(msg)) end
end

local function notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

--- The name of a started resource MULTIhunting stands down for, or nil.
function MH.StandingDownFor()
    for _, name in ipairs(Config.StandDownFor or {}) do
        if GetResourceState(name) == 'started' then return name end
    end
    return nil
end

local function clampGrade(g)
    g = math.tointeger(tonumber(g))
    if not g or g < 0 then return nil end
    return math.min(g, 2)
end

--- The pelt grade (0 poor, 1 good, 2 perfect) from the game's animal quality and kill cleanliness.
function MH.Grade(quality, cleanliness)
    local q, c = clampGrade(quality), clampGrade(cleanliness)
    local mode = Config.Quality.Mode
    local g
    if mode == 'quality' then g = q
    elseif mode == 'cleanliness' then g = c
    elseif q and c then g = math.min(q, c)
    else g = q or c end
    return g or Config.Quality.Default
end

--- The items an animal gives at a grade: list of { name, amount, info? }.
function MH.RewardsFor(def, grade)
    local out = {}
    if def.whole then
        out[#out + 1] = { name = def.whole, amount = 1 }
        return out
    end
    if def.pelt then
        local g = def.legendary and 2 or (clampGrade(grade) or Config.Quality.Default)
        if type(def.pelt) == 'table' then
            local key = ({ [0] = 'poor', [1] = 'good', [2] = 'perfect' })[g]
            local item = def.pelt[key] or def.pelt.good
            if item then out[#out + 1] = { name = item, amount = 1 } end
        else
            out[#out + 1] = { name = def.pelt, amount = 1, info = { quality = Config.Quality.Percent[g] or 100 } }
        end
    end
    local meat = math.tointeger(tonumber(def.meat)) or 0
    if meat > 0 then out[#out + 1] = { name = def.meatItem or Config.MeatItem, amount = meat } end
    for _, p in ipairs(def.parts or {}) do
        if type(p) == 'table' then
            out[#out + 1] = { name = p[1] or p.name, amount = math.tointeger(tonumber(p[2] or p.amount)) or 1 }
        else
            out[#out + 1] = { name = p, amount = 1 }
        end
    end
    return out
end

local function forgetOld()
    local now = os.time()
    for id, rec in pairs(MH.Skinned) do
        if now - rec.at > Config.CarcassMemorySeconds then MH.Skinned[id] = nil end
    end
end

--- Has this carcass (network id, and model when given) paid already?
function MH.IsCarcassSkinned(netId, model)
    netId = math.tointeger(tonumber(netId))
    if not netId or netId <= 0 then return false end
    local rec = MH.Skinned[netId]
    if not rec or os.time() - rec.at > Config.CarcassMemorySeconds then return false end
    -- network ids are reused once an entity is gone: a different model is a different carcass
    local h = model and MH.Hash(model)
    if h and rec.model ~= h then return false end
    return true
end

local function hasTool(pid, def)
    local need = Config.RequireItems or {}
    if #need == 0 then return true end
    if def.whole and not Config.RequireItemsForWhole then return true end
    for _, name in ipairs(need) do
        if (tonumber(MI:Count(pid, name)) or 0) > 0 then return true end
    end
    return false
end

--- Checks the carcass when the server can see it (OneSync). → true | false, err
local function checkCarcass(src, netId, hash)
    if not netId or netId <= 0 then
        if Config.RequireNetworkedCarcass then return false, 'not_networked' end
        return true
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        if Config.RequireNetworkedCarcass then return false, 'not_networked' end
        return true
    end
    if MH.Hash(GetEntityModel(ent)) ~= hash then return false, 'wrong_model' end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(ent)) > Config.MaxDistance then
        return false, 'too_far'
    end
    return true
end

--- Gives the skinning reward for an animal model at a grade, once per carcass.
--- → true, given (list of { name, amount, info }) | false, err
--- err: no_player, stand_down, unknown_animal, cooldown, already_skinned, not_networked,
---      wrong_model, too_far, need_tool, no_space, too_heavy, limit, failed
function MH.Reward(src, model, grade, netId)
    src = tonumber(src)
    local P = src and RSGCore.Functions.GetPlayer(src)
    if not P then return false, 'no_player' end
    if MH.StandingDownFor() then return false, 'stand_down' end
    local hash = MH.Hash(model)
    local def = hash and MH.ByHash[hash]
    if not def then return false, 'unknown_animal' end

    local now = GetGameTimer()
    if MH.LastReward[src] and now - MH.LastReward[src] < Config.PlayerCooldownMs then return false, 'cooldown' end

    netId = math.tointeger(tonumber(netId))
    forgetOld()
    if MH.IsCarcassSkinned(netId, hash) then return false, 'already_skinned' end
    local ok, err = checkCarcass(src, netId, hash)
    if not ok then return false, err end

    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not hasTool(pid, def) then return false, 'need_tool' end

    local list = MH.RewardsFor(def, grade)
    for _, it in ipairs(list) do
        local can, cerr = MI:CanAdd(pid, it.name, it.amount, it.info)
        if not can then return false, cerr or 'no_space' end
    end

    -- claim the carcass and the cooldown before anything is given (no double pay on a resend)
    MH.LastReward[src] = now
    if netId and netId > 0 then MH.Skinned[netId] = { model = hash, at = os.time() } end

    local given = {}
    for _, it in ipairs(list) do
        local added, aerr = MI:AddItem(pid, it.name, it.amount, it.info, nil, 'hunting ' .. def.model)
        if not added then
            -- take back what was given, free the carcass again
            for _, g in ipairs(given) do MI:RemoveItem(pid, g.name, g.amount, nil, g.info, 'hunting rollback') end
            if netId and netId > 0 then MH.Skinned[netId] = nil end
            MH.LastReward[src] = nil
            return false, aerr or 'failed'
        end
        given[#given + 1] = it
        MI:ItemBox(src, it.name, it.amount, 'add')
    end

    dbg(('%s skinned %s (grade %s, carcass %s): %d item kinds'):format(src, def.model, tostring(grade), tostring(netId), #given))
    TriggerEvent('MULTIhunting:skinned', src, def.model, def.legendary and 2 or grade, given)
    return true, given
end

local function labelOf(name)
    local d = MI:GetItemDef(name)
    return d and d.label or name
end

local function summary(given, grade, def)
    local parts = {}
    for i, it in ipairs(given) do
        local text = labelOf(it.name)
        if it.amount > 1 then text = ('%s x%d'):format(text, it.amount) end
        if i == 1 and it.info and it.info.quality and not def.whole then
            text = ('%s (%s)'):format(text, _L('grade_' .. tostring(def.legendary and 2 or grade)))
        end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ', ')
end

local refusals = {
    already_skinned = 'already_skinned',
    need_tool = 'need_tool',
    no_space = 'inventory_full',
    too_heavy = 'inventory_full',
    limit = 'inventory_full',
    too_far = 'too_far',
}

-- the client reports a finished skinning: model, the game's quality and cleanliness, carcass net id
lib.callback.register('MULTIhunting:skinned', function(src, model, quality, cleanliness, netId)
    if type(model) ~= 'number' then return false, 'unknown_animal' end
    local def = MH.Animal(model)
    if not def then return false, 'unknown_animal' end
    local grade = MH.Grade(quality, cleanliness)
    local ok, res = MH.Reward(src, model, grade, netId)
    if ok then
        if Config.NotifySummary then notify(src, _L('skinned', summary(res, grade, def)), 'success') end
        return true
    end
    dbg(('%s refused (%s) for %s'):format(src, tostring(res), def.model))
    if refusals[res] then
        local key = refusals[res]
        if key == 'need_tool' then
            notify(src, _L('need_tool', labelOf((Config.RequireItems or {})[1] or '')), 'error')
        else
            notify(src, _L(key), 'error')
        end
    end
    return false, res
end)

-- items the animal table names but the registry does not have are registered, so rewards never fail
local function registerMissing()
    local seen = {}
    local function want(name)
        if type(name) ~= 'string' or seen[name] then return end
        seen[name] = true
        if not MI:GetItemDef(name) then
            local label = name:gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)
            MI:RegisterItem({ name = name, label = label, weight = 100, type = 'item', image = name .. '.png' })
            print(('^3[MULTIhunting] item %s was not in the registry - registered it (add it to a store to sell it)^7'):format(name))
        end
    end
    want(Config.MeatItem)
    for _, def in pairs(Config.Animals) do
        want(def.whole); want(def.meatItem)
        if type(def.pelt) == 'table' then for _, v in pairs(def.pelt) do want(v) end else want(def.pelt) end
        for _, p in ipairs(def.parts or {}) do want(type(p) == 'table' and (p[1] or p.name) or p) end
    end
end

MH.ready = false
CreateThread(function()
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    registerMissing()
    MH.ready = true
    local other = MH.StandingDownFor()
    if other then
        print(('^3[MULTIhunting] %s is running: MULTIhunting gives no skinning rewards (Config.StandDownFor)^7'):format(other))
    end
end)

AddEventHandler('playerDropped', function()
    MH.LastReward[source] = nil
end)

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('Reward', MH.Reward)
exports('Grade', MH.Grade)
exports('IsCarcassSkinned', MH.IsCarcassSkinned)
exports('IsReady', function() return MH.ready end)
exports('GetAnimal', function(model)
    local def = MH.Animal(model)
    if not def then return nil end
    return json.decode(json.encode(def))
end)
exports('GetRewards', function(model, grade)
    local def = MH.Animal(model)
    if not def then return nil end
    return MH.RewardsFor(def, grade)
end)
