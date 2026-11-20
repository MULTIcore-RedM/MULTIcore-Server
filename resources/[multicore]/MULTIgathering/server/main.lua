-- ============================================================
-- MULTIgathering :: server core
-- Shared server rules for every activity: who may work (logged in, not standing down,
-- not spamming), the player's position (OneSync), chance tables, giving items all-or-nothing,
-- notifications, item registration and the exports. Activities: server/work.lua (mining,
-- lumber, panning), server/fishing.lua, server/herbs.lua.
-- ============================================================

RSGCore = exports['rsg-core']:GetCoreObject()
MI = exports.MULTIinventory

MG.ready = false
MG.clockOffset = 0      -- self-test only: moves the clock forward (see the test hooks below)
MG.random = math.random -- self-test only: replaced to make rolls predictable
MG.fakeCoords = {}      -- self-test only: positions for pretend players
local lastCall = {}     -- [src] = { [kind] = ms }
MG.UsableHooks = {}     -- functions run once the inventory is ready (each registers its usable items)
MG.DropHooks = {}       -- functions run with src when a player leaves

--- The server's clock in ms.
function MG.Now() return GetGameTimer() + MG.clockOffset end

function MG.Debug(msg)
    if Config.Debug then print(('[MULTIgathering] %s'):format(msg)) end
end

function MG.Notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

--- The name of a started resource this activity stands down for, or nil.
function MG.StandingDownFor(activity)
    for _, name in ipairs((Config.StandDownFor or {})[activity] or {}) do
        if GetResourceState(name) == 'started' then return name end
    end
    return nil
end

--- Is the activity switched on and not standing down? → true | false, err
function MG.Active(activity)
    local cfg = ({ fishing = Config.Fishing, mining = Config.Mining, panning = Config.Panning, lumber = Config.Lumber, herbs = Config.Herbs })[activity]
    if not cfg or not cfg.Enabled then return false, 'disabled' end
    if MG.StandingDownFor(activity) then return false, 'stand_down' end
    return true
end

--- true when the same player sent the same kind of request within Config.RateLimitMs.
function MG.RateLimited(src, kind)
    local now = MG.Now()
    local t = lastCall[src] or {}
    lastCall[src] = t
    if t[kind] and now - t[kind] < Config.RateLimitMs then return true end
    t[kind] = now
    return false
end

function MG.Player(src)
    src = tonumber(src)
    return src and RSGCore.Functions.GetPlayer(src) or nil
end

--- The player's position as the server sees it (OneSync), or nil.
function MG.PlayerCoords(src)
    local fake = MG.fakeCoords[src]
    if fake then return fake end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- Is the player within `radius` of `coords`? Unknown position: Config.AllowWithoutPosition.
function MG.PlayerNear(src, coords, radius)
    local pos = MG.PlayerCoords(src)
    if not pos then return Config.AllowWithoutPosition == true end
    return MG.Near(pos, coords, radius)
end

function MG.Has(pid, item)
    return item and (tonumber(MI:Count(pid, item)) or 0) > 0
end

function MG.Label(name)
    local d = MI:GetItemDef(name)
    return d and d.label or name
end

--- Rolls a chance table: { { item, chance, min, max }, ..., fallback = { item, amount } }.
--- → list of { name, amount } (amounts of the same item added up)
function MG.Roll(tbl)
    local out, idx = {}, {}
    local function add(name, n)
        if not name or n <= 0 then return end
        if idx[name] then out[idx[name]].amount = out[idx[name]].amount + n
        else out[#out + 1] = { name = name, amount = n }; idx[name] = #out end
    end
    for _, line in ipairs(tbl or {}) do
        local chance = tonumber(line.chance) or 0
        if MG.random() * 100 < chance then
            local lo = math.tointeger(tonumber(line.min)) or 1
            local hi = math.max(lo, math.tointeger(tonumber(line.max)) or lo)
            add(line.item, lo == hi and lo or MG.random(lo, hi))
        end
    end
    if #out == 0 and tbl and tbl.fallback then add(tbl.fallback.item, math.tointeger(tonumber(tbl.fallback.amount)) or 1) end
    return out
end

--- Gives every item or none. → true, given | false, err
function MG.GiveAll(src, pid, list, reason)
    for _, it in ipairs(list) do
        local ok, err = MI:CanAdd(pid, it.name, it.amount, it.info)
        if not ok then return false, err or 'no_space' end
    end
    local given = {}
    for _, it in ipairs(list) do
        local ok, err = MI:AddItem(pid, it.name, it.amount, it.info, nil, reason)
        if not ok then
            for _, g in ipairs(given) do MI:RemoveItem(pid, g.name, g.amount, nil, g.info, reason .. ' rollback') end
            return false, err or 'failed'
        end
        given[#given + 1] = it
        MI:ItemBox(src, it.name, it.amount, 'add')
    end
    return true, given
end

--- "Coal x2, Rock" for a note.
function MG.Summary(given)
    local parts = {}
    for _, it in ipairs(given or {}) do
        local text = MG.Label(it.name)
        if it.amount > 1 then text = ('%s x%d'):format(text, it.amount) end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ', ')
end

--- Possibly breaks the tool after a finished job. → true when it broke
function MG.MaybeBreak(src, pid, tool, chance)
    chance = tonumber(chance) or 0
    if chance <= 0 or not tool then return false end
    if MG.random() * 100 >= chance then return false end
    if MI:RemoveItem(pid, tool, 1, nil, nil, 'gathering tool broke') then
        MI:ItemBox(src, tool, 1, 'remove')
        MG.Notify(src, _L('tool_broke', MG.Label(tool)), 'error')
        return true
    end
    return false
end

-- refusals a player is told about (others stay silent: they only happen with a forged client)
local refusalKeys = {
    need_tool = 'need_tool', no_space = 'inventory_full', too_heavy = 'inventory_full', limit = 'inventory_full',
    depleted = 'depleted', too_far = 'too_far', cooldown = 'cooldown', no_zone = 'no_zone', busy = 'busy',
    not_held = 'need_rod', no_cast = 'no_cast', no_bait = 'need_bait',
}

--- Tells the player why something was refused (when it is something they can fix).
function MG.Refuse(src, err, tool)
    local key = refusalKeys[err]
    MG.Debug(('%s refused: %s'):format(tostring(src), tostring(err)))
    if not key then return end
    if key == 'need_tool' or key == 'need_bait' then
        MG.Notify(src, _L(key, MG.Label(tool or '')), 'error')
    else
        MG.Notify(src, _L(key), 'error')
    end
end

---------------------------------
-- items: register what is missing
---------------------------------
local function registerMissing()
    local seen = {}
    local function want(name, def)
        if type(name) ~= 'string' or seen[name] then return end
        seen[name] = true
        if MI:GetItemDef(name) then return end
        if not def then
            local label = name:gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)
            def = { name = name, label = label, weight = 100, type = 'item', image = name .. '.png' }
            print(('^3[MULTIgathering] item %s was not in the registry - registered it (add it to a store to sell it)^7'):format(name))
        end
        MI:RegisterItem(def)
    end
    for name, def in pairs(Config.NewItems or {}) do want(name, def) end
    want(Config.Fishing.Rod); want(Config.Mining.Tool); want(Config.Panning.Tool); want(Config.Lumber.Tool)
    for _, b in ipairs(Config.Fishing.Baits or {}) do want(b) end
    for _, f in pairs(Config.Fish or {}) do want(f.item) end
    local function tableItems(t)
        for _, line in ipairs(t or {}) do want(line.item) end
        if t and t.fallback then want(t.fallback.item) end
    end
    for _, t in pairs(Config.MiningRewards or {}) do tableItems(t) end
    for _, t in pairs(Config.LumberRewards or {}) do tableItems(t) end
    tableItems(Config.PanningRewards)
    for _, item in pairs(Config.HerbItems or {}) do want(item) end
end

CreateThread(function()
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    registerMissing()
    for _, fn in ipairs(MG.UsableHooks) do fn() end
    MG.ready = true
    for _, a in ipairs({ 'fishing', 'mining', 'panning', 'lumber', 'herbs' }) do
        local other = MG.StandingDownFor(a)
        if other then print(('^3[MULTIgathering] %s is running: MULTIgathering gives no %s rewards (Config.StandDownFor)^7'):format(other, a)) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastCall[src] = nil
    for _, fn in ipairs(MG.DropHooks) do fn(src) end
end)

-- the client asks which activities are off (so it shows no prompts for them)
lib.callback.register('MULTIgathering:active', function(src)
    local out = {}
    for _, a in ipairs({ 'fishing', 'mining', 'panning', 'lumber', 'herbs' }) do out[a] = MG.Active(a) == true end
    return out
end)

---------------------------------
-- admin: print a ready config line for the spot the admin stands on
---------------------------------
RSGCore.Commands.Add('gatherspot', _L('cmd_gatherspot'), {}, false, function(src)
    local pos = MG.PlayerCoords(src)
    if not pos then return end
    local line = ('coords = vector3(%.2f, %.2f, %.2f)'):format(pos.x, pos.y, pos.z)
    print(('[MULTIgathering] %s'):format(line))
    TriggerClientEvent('MULTIgathering:client:spotLine', src, line)
end, 'admin')

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true; never on a live server)
---------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestSetCoords', function(src, x, y, z)
        src = tonumber(src)
        if not src then return false end
        MG.fakeCoords[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
    exports('_TestAdvance', function(ms) MG.clockOffset = MG.clockOffset + (tonumber(ms) or 0) return MG.Now() end)
    exports('_TestSetRoll', function(value)
        if value == nil then MG.random = math.random return true end
        -- a fixed roll: random() -> value (0..1), random(lo, hi) -> hi when value >= 0.5 else lo
        MG.random = function(lo, hi)
            if lo == nil then return value end
            if hi == nil then hi, lo = lo, 1 end
            return value >= 0.5 and hi or lo
        end
        return true
    end)
end
