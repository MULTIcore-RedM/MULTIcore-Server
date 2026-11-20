-- ============================================================
-- MULTIinventory :: server/core/boot.lua - loaded LAST
--
-- Start order: oxmysql ready -> schema migration (sql/install.sql) -> stack id
-- allocator -> item registry -> world drops -> ready -> attach online players.
-- Background loops: save (write-behind), audit log, drop sweep, decay tick,
-- idle offline container unload, NUI delta push (sync.lua).
-- Server-local event on ready: MULTIinventory:ready
-- ============================================================

local RES = GetCurrentResourceName()

State.wireFramework()

CreateThread(function()
    if not InvDB.boot() then
        print('^1[MULTIinventory] database not available - inventory NOT started^7')
        return
    end
    Persistence.init()
    Registry.reload()
    Drops.init()
    if MultiInv and MultiInv.beforeReady then
        local ok, err = pcall(MultiInv.beforeReady)
        if not ok then print('^1[MULTIinventory] start-up: ' .. tostring(err) .. '^7') end
    end
    InvDB.setReady()
    State.attachOnline()
    TriggerEvent('MULTIinventory:ready')
    print('[MULTIinventory] ready')
end)

local function loop(seconds, fn, name)
    CreateThread(function()
        InvDB.awaitReady()
        while true do
            Wait(math.max(1, seconds()) * 1000)
            local ok, err = pcall(fn)
            if not ok then print(('^1[MULTIinventory] %s: %s^7'):format(name, tostring(err))) end
        end
    end)
end

loop(function() return Config.Persistence.saveIntervalSeconds end, function() Persistence.flush() end, 'save')
loop(function() return Config.Log.flushSeconds end, function() InvLog.flush() end, 'log')
loop(function() return Config.Drop.sweepSeconds end, function() Drops.sweep() end, 'drops')

local lastTick = os.time()
loop(function() return Config.Degradation.tickSeconds end, function()
    local now = os.time()
    Degradation.tick(now - lastTick)
    lastTick = now
end, 'decay')

-- offline containers (stashes, offline players touched by scripts) leave the cache when idle
loop(function() return 60 end, function()
    local cutoff = Util.now() - (Config.Persistence.unloadOfflineAfter or 600)
    local victims = {}
    Containers.each(function(c)
        if c.kind ~= 'drop' and c.lastUsed < cutoff and next(State.viewersOf(c.id)) == nil then
            local online = c.ownerCharId and (c.kind == 'player' or c.kind == 'equip') and State.srcOfChar(c.ownerCharId)
            if not online then victims[#victims + 1] = c.id end
        end
    end)
    for _, id in ipairs(victims) do Containers.unload(id) end
end, 'unload')

AddEventHandler('onResourceStop', function(res)
    if res ~= RES or not InvDB.ready() then return end
    Persistence.flush(nil, true)
    InvLog.flush(true)
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    CreateThread(function()
        Persistence.flush()
        InvLog.flush()
    end)
end)
