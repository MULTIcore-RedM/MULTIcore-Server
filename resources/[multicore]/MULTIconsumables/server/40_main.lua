-- ============================================================
-- MULTIconsumables :: timers and exports (server)
-- ============================================================

---------------------------------
-- timers: sobering, addiction, pending uses, blackout safety, saving
---------------------------------
CreateThread(function()
    local lastDrunk, lastAdd = os.time(), os.time()
    while true do
        Wait(1000)
        local now = os.time()
        local gt = GetGameTimer()

        for src, p in pairs(MC.Pending) do
            if gt > p.expires then MC.Pending[src] = nil end   -- client never reported back: the item stays used
        end
        for src, b in pairs(MC.Blackout) do
            if now >= b.wakeBy then MC.Drunk.Wake(src) end
        end

        local doDrunk = now - lastDrunk >= Config.Drunk.TickSeconds
        local doAdd = now - lastAdd >= Config.Addiction.TickSeconds
        if doDrunk or doAdd then
            for src, s in pairs(MC.State) do
                local P = MC.Player(src)
                if not P or P.PlayerData.citizenid ~= s.cid then
                    MC.State[src] = nil
                else
                    if doDrunk then MC.Drunk.Tick(src, s, now - lastDrunk) end
                    if doAdd then MC.Addiction.Tick(src, s, now) end
                    if s.dirty then MC.Save(src) end
                end
            end
            if doDrunk then lastDrunk = now end
            if doAdd then lastAdd = now end
        end
    end
end)

---------------------------------
-- exports (server)
---------------------------------
local function subst(name) return type(name) == 'string' and Config.Addiction.Substances[name] ~= nil end

--- Drunk level of a player (0 .. Config.Drunk.Max) or nil.
exports('GetDrunk', function(src) return MC.Drunk.Get(src) end)
--- Sets the drunk level. → new level or nil
exports('SetDrunk', function(src, value) local v = MC.Drunk.Set(src, value); MC.Save(src); return v end)
--- Adds to (or with a negative number takes from) the drunk level. → new level or nil
exports('AddDrunk', function(src, delta) local v = MC.Drunk.Add(src, delta); MC.Save(src); return v end)
--- Is the player passed out?
exports('IsBlackedOut', function(src) return MC.Blackout[tonumber(src)] ~= nil end)

--- Addiction level (0-100) of a substance, or nil.
exports('GetAddiction', function(src, substance)
    if not subst(substance) then return nil end
    local s = MC.Get(src)
    if not s then return nil end
    local d = s.add[substance]
    return d and d.level or 0
end)
--- Sets an addiction level. lastUseSecondsAgo optional. → bool
exports('SetAddiction', function(src, substance, level, lastUseSecondsAgo)
    if not subst(substance) then return false end
    return MC.Addiction.Set(src, substance, level, lastUseSecondsAgo)
end)
--- 'none' | 'ok' | 'craving' | 'withdrawal'
exports('GetAddictionStatus', function(src, substance)
    if not subst(substance) then return nil end
    local s = MC.Get(src)
    return s and MC.Addiction.Status(s, substance) or nil
end)
exports('IsInWithdrawal', function(src, substance)
    local s = MC.Get(src)
    if not s then return false end
    if substance then return MC.Addiction.Status(s, substance) == 'withdrawal' end
    for name in pairs(Config.Addiction.Substances) do
        if MC.Addiction.Status(s, name) == 'withdrawal' then return true end
    end
    return false
end)

--- Uses one of an item from the player's satchel, as if they used it themselves
--- (animation and all). opts = { free = true } applies it without taking an item,
--- { noAnim = true } skips the animation. → true | false, err
exports('Consume', function(src, itemName, opts)
    return MC.Use(src, itemName, nil, opts)
end)
--- Is the item one MULTIconsumables knows? → its effect table (copy) or nil
exports('GetConsumable', function(itemName) return Config.Consumables[itemName] end)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true)
---------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    --- Runs one timer step now: kind = 'drunk' (as if `seconds` passed) or 'addiction'.
    exports('_TestTick', function(src, kind, seconds)
        local s = MC.Get(src)
        if not s then return false end
        if kind == 'drunk' then MC.Drunk.Tick(src, s, tonumber(seconds) or Config.Drunk.TickSeconds)
        elseif kind == 'addiction' then MC.Addiction.Tick(src, s, os.time()) end
        MC.Save(src)
        return true
    end)
    --- Changes a substance's timings (cravingAfter, withdrawalAfter, recoverAfter ...).
    exports('_TestSetTiming', function(substance, values)
        local c = Config.Addiction.Substances[substance]
        if not c or type(values) ~= 'table' then return false end
        for k, v in pairs(values) do c[k] = v end
        return true
    end)
    --- Clears the use cooldown so a test can use items back to back.
    exports('_TestClearBusy', function(src) MC.Busy[tonumber(src)] = nil; MC.Pending[tonumber(src)] = nil; return true end)
end
