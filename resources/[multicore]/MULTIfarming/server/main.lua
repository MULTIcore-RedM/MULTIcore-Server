-- ============================================================
-- MULTIfarming :: server core
-- Shared server rules: who may work (logged in, not spamming), the player's position
-- (OneSync), giving items all-or-nothing, notifications, item registration, the database
-- table and loading the crops at start. Crops and jobs: server/plants.lua.
-- ============================================================

Core = exports.MULTIcore:GetCoreObject()
MI = exports.MULTIinventory

FM.ready = false
FM.random = math.random  -- self-test only: replaced to make rolls predictable
FM.fakeCoords = {}       -- self-test only: positions for pretend players
FM.UsableHooks = {}      -- functions run once the inventory is ready (each registers its usable items)
FM.DropHooks = {}        -- functions run with src when a player leaves
FM.LoadHooks = {}        -- functions run once with the database rows at start
local lastCall = {}      -- [src] = { [kind] = ms }

--- The server's clock in ms (rate limits and work times).
function FM.Now() return GetGameTimer() end

--- Unix seconds (growth; saved in the database).
function FM.Time() return os.time() end

function FM.Debug(msg)
    if Config.Debug then print(('[MULTIfarming] %s'):format(msg)) end
end

function FM.Notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

--- true when the same player sent the same kind of request within Config.RateLimitMs.
function FM.RateLimited(src, kind)
    local now = FM.Now()
    local t = lastCall[src] or {}
    lastCall[src] = t
    if t[kind] and now - t[kind] < Config.RateLimitMs then return true end
    t[kind] = now
    return false
end

function FM.Player(src)
    src = tonumber(src)
    return src and Core.Functions.GetPlayer(src) or nil
end

--- The character id of a logged-in player, or nil.
function FM.CitizenId(src)
    local p = FM.Player(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

--- The player's position as the server sees it (OneSync), or nil.
function FM.PlayerCoords(src)
    local fake = FM.fakeCoords[src]
    if fake then return fake end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 and c.z == 0.0 then return nil end
    return c
end

--- Is the player within `radius` of `coords` (3D)? Unknown position: Config.AllowWithoutPosition.
function FM.PlayerNear(src, coords, radius)
    local pos = FM.PlayerCoords(src)
    if not pos then return Config.AllowWithoutPosition == true end
    return #(vector3(pos.x, pos.y, pos.z) - vector3(coords.x, coords.y, coords.z)) <= radius
end

function FM.Count(pid, item)
    return item and (tonumber(MI:Count(pid, item)) or 0) or 0
end

function FM.Label(name)
    local d = MI:GetItemDef(name)
    return d and d.label or name
end

--- Gives every item or none. → true, given | false, err
function FM.GiveAll(src, pid, list, reason)
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

--- "Corn x3, Corn Seeds" for a note.
function FM.Summary(given)
    local parts = {}
    for _, it in ipairs(given or {}) do
        local text = FM.Label(it.name)
        if it.amount > 1 then text = ('%s x%d'):format(text, it.amount) end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ', ')
end

-- refusals a player is told about (others stay silent: they only happen with a forged client)
local refusalKeys = {
    need_tool = 'need_tool', no_seed = 'no_seed', limit = 'limit', too_close = 'too_close', no_zone = 'no_zone',
    too_far = 'too_far', busy = 'busy', cooldown = 'cooldown', no_space = 'inventory_full', too_heavy = 'inventory_full',
    not_owner = 'not_owner', not_ripe = 'not_ripe', dead = 'dead_crop', gone = 'gone', can_empty = 'can_empty',
    can_full = 'can_full', wet_enough = 'wet_enough',
}

--- Tells the player why something was refused (when it is something they can fix).
function FM.Refuse(src, err, arg)
    local key = refusalKeys[err]
    FM.Debug(('%s refused: %s'):format(tostring(src), tostring(err)))
    if not key then return end
    if key == 'need_tool' then
        FM.Notify(src, _L(key, FM.Label(arg or '')), 'error')
    elseif key == 'limit' then
        FM.Notify(src, _L(key, Config.Planting.MaxPlantsPerPlayer), 'error')
    else
        FM.Notify(src, _L(key), 'error')
    end
end

---------------------------------
-- admin check: MULTIcore permission levels or the ace
---------------------------------
function FM.IsAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src then return false end
    if Config.Admin.Ace and IsPlayerAceAllowed(src, Config.Admin.Ace) then return true end
    local ok, res = pcall(function() return Core.Functions.HasPermission(src, Config.Admin.Groups) end)
    return ok and res == true
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
            print(('^3[MULTIfarming] item %s was not in the registry - registered it (add it to a store to sell it)^7'):format(name))
        end
        MI:RegisterItem(def)
    end
    for name, def in pairs(Config.NewItems or {}) do want(name, def) end
    want(Config.Planting.Tool); want(Config.Watering.Can)
    for _, c in pairs(Config.Crops or {}) do want(c.seed); want(c.item) end
end

---------------------------------
-- database
---------------------------------
local SCHEMA = [[CREATE TABLE IF NOT EXISTS `multi_farming_plants` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `crop` VARCHAR(32) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `progress` DOUBLE NOT NULL DEFAULT 0,
    `water` DOUBLE NOT NULL DEFAULT 0,
    `updated` INT NOT NULL DEFAULT 0,
    `dry_at` INT DEFAULT NULL,
    `ripe_at` INT DEFAULT NULL,
    `dead_at` INT DEFAULT NULL,
    `planted` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

CreateThread(function()
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    registerMissing()
    for _, fn in ipairs(FM.UsableHooks) do fn() end
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) end)
    if not ok then print(('^1[MULTIfarming] could not create the table multi_farming_plants: %s^7'):format(tostring(err))) end
    local rows = ok and MySQL.query.await('SELECT * FROM `multi_farming_plants`') or {}
    for _, fn in ipairs(FM.LoadHooks) do fn(rows or {}) end
    FM.ready = true
    print(('[MULTIfarming] %d crops loaded'):format(#(rows or {})))
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastCall[src] = nil
    for _, fn in ipairs(FM.DropHooks) do fn(src) end
end)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true; never on a live server)
---------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestSetCoords', function(src, x, y, z)
        src = tonumber(src)
        if not src then return false end
        FM.fakeCoords[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
end
