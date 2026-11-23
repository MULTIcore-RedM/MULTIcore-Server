-- ============================================================
-- MULTIgathering :: rock faces added in game (server)
-- Admins stand at a rock face and type  /minespot add <rewards> [radius]  to make it a mining
-- spot at once (no restart). /minespot remove  deletes the nearest added spot within 10 m.
-- Added spots are kept in data/mining_spots.json of this resource and loaded on every start,
-- next to the spots in config/mining.lua.
-- ============================================================

local FILE = 'data/mining_spots.json'
local added = {}   -- list of spot defs made in game

local function save()
    local out = {}
    for _, s in ipairs(added) do
        out[#out + 1] = { id = s.id, mine = s.mine, x = s.coords.x, y = s.coords.y, z = s.coords.z,
            radius = s.radius, charges = s.charges, respawnMinutes = s.respawnMinutes, rewards = s.rewards }
    end
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(out, { indent = true }), -1)
end

local function register(s)
    added[#added + 1] = s
    Config.MiningSpots[#Config.MiningSpots + 1] = s
    MG.Spots[s.id] = { kind = 'mining', def = s }
end

local function unregister(id)
    for i, s in ipairs(added) do if s.id == id then table.remove(added, i) break end end
    for i, s in ipairs(Config.MiningSpots) do if s.id == id then table.remove(Config.MiningSpots, i) break end end
    MG.Spots[id], MG.SpotState[id] = nil, nil
end

-- load what earlier admins added
do
    Config.MiningSpots = Config.MiningSpots or {}
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local ok, list = pcall(json.decode, raw or '[]')
    for _, e in ipairs(ok and type(list) == 'table' and list or {}) do
        if type(e.id) == 'string' and tonumber(e.x) and Config.MiningRewards[e.rewards] and not MG.Spots[e.id] then
            register({
                id = e.id, mine = e.mine or 'custom', coords = vector3(e.x + 0.0, e.y + 0.0, e.z + 0.0),
                radius = tonumber(e.radius) or 6.0, charges = tonumber(e.charges) or 6,
                respawnMinutes = tonumber(e.respawnMinutes) or 15, rewards = e.rewards,
            })
        end
    end
    if #added > 0 then print(('[MULTIgathering] %d rock faces added in game loaded (%s)'):format(#added, FILE)) end
end

--- client: the spots added in game (sent once after login, then live on change)
local function wire(s)
    return { id = s.id, mine = s.mine, x = s.coords.x, y = s.coords.y, z = s.coords.z, radius = s.radius,
        charges = s.charges, respawnMinutes = s.respawnMinutes, rewards = s.rewards }
end

lib.callback.register('MULTIgathering:addedSpots', function()
    local out = {}
    for _, s in ipairs(added) do out[#out + 1] = wire(s) end
    return out
end)

--- nearest mine name in config/mining.lua (so a new face joins that mine's blip), else 'custom'
local function nearestMine(pos)
    local best, bestD = 'custom', 400.0
    for _, s in ipairs(Config.MiningSpots) do
        local d = #(vector3(pos.x, pos.y, 0.0) - vector3(s.coords.x, s.coords.y, 0.0))
        if d < bestD then best, bestD = s.mine, d end
    end
    return best
end

RSGCore.Commands.Add('minespot', _L('cmd_minespot'), {
    { name = 'add|remove', help = _L('cmd_minespot_action') },
    { name = 'rewards', help = _L('cmd_minespot_rewards') },
    { name = 'radius', help = _L('cmd_minespot_radius') },
}, false, function(src, args)
    local pos = MG.PlayerCoords(src)
    if not pos then return end
    local action = tostring(args[1] or ''):lower()
    if action == 'add' then
        local rewards = tostring(args[2] or '')
        if not Config.MiningRewards[rewards] then
            local names = {}
            for k in pairs(Config.MiningRewards) do names[#names + 1] = k end
            table.sort(names)
            return MG.Notify(src, _L('minespot_usage', table.concat(names, ', ')), 'error')
        end
        local radius = math.max(2.0, math.min(tonumber(args[3]) or 6.0, 20.0))
        local id = ('added_%d_%d'):format(os.time(), math.random(1000, 9999))
        local s = { id = id, mine = nearestMine(pos), coords = vector3(pos.x, pos.y, pos.z), radius = radius,
            charges = 6, respawnMinutes = 15, rewards = rewards }
        register(s)
        save()
        TriggerClientEvent('MULTIgathering:client:spotAdded', -1, wire(s))
        MG.Notify(src, _L('minespot_added', rewards), 'success')
        print(('[MULTIgathering] rock face %s added by %s at %.2f, %.2f, %.2f (%s)'):format(id, GetPlayerName(src) or src, pos.x, pos.y, pos.z, rewards))
    elseif action == 'remove' then
        local best, bestD
        for _, s in ipairs(added) do
            local d = #(pos - s.coords)
            if d <= 10.0 and (not bestD or d < bestD) then best, bestD = s, d end
        end
        if not best then return MG.Notify(src, _L('minespot_none'), 'error') end
        unregister(best.id)
        save()
        TriggerClientEvent('MULTIgathering:client:spotRemoved', -1, best.id)
        MG.Notify(src, _L('minespot_removed'), 'success')
    else
        local names = {}
        for k in pairs(Config.MiningRewards) do names[#names + 1] = k end
        table.sort(names)
        MG.Notify(src, _L('minespot_usage', table.concat(names, ', ')), 'error')
    end
end, 'admin')
