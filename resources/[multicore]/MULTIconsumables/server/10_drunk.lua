-- ============================================================
-- MULTIconsumables :: drunk level (server)
-- The level lives on the server and in the metadata ('multi_drunk'). The client only shows it.
-- ============================================================

MC.Drunk = {}
local D = MC.Drunk

--- Index of the drunk level table that applies (0 = sober).
function D.LevelIndex(v)
    local idx = 0
    for i, L in ipairs(Config.Drunk.Levels) do
        if v >= L.min then idx = i end
    end
    return idx
end

--- Sets the drunk level. → the new level or nil
function D.Set(src, value)
    if not Config.Drunk.Enabled then return nil end
    local s = MC.Get(src)
    if not s then return nil end
    value = tonumber(value) or 0
    value = math.max(0, math.min(Config.Drunk.Max, value))
    local old = s.drunk
    s.drunk = value
    s.dirty = true

    if Config.Drunk.NotifyLevels then
        local oi, ni = D.LevelIndex(old), D.LevelIndex(value)
        if ni > oi then
            MC.Notify(src, 'drunk_' .. Config.Drunk.Levels[ni].key, 'warning')
        elseif ni == 0 and oi > 0 then
            MC.Notify(src, 'drunk_sober', 'success')
        end
    end
    TriggerClientEvent('MULTIconsumables:client:drunk', src, MC.Round2(value))

    local B = Config.Drunk.Blackout
    if B.Enabled and value >= B.At and not MC.Blackout[tonumber(src)] then D.StartBlackout(src) end
    if math.abs(value - old) >= 0.01 then MC.Debug('drunk %s: %.2f -> %.2f', src, old, value) end
    return value
end

function D.Add(src, delta)
    local s = MC.Get(src)
    if not s then return nil end
    return D.Set(src, s.drunk + (tonumber(delta) or 0))
end

function D.Get(src)
    local s = MC.Get(src)
    return s and s.drunk or nil
end

--- Sobering with time: `seconds` of real time have passed.
function D.Tick(src, s, seconds)
    if s.drunk <= 0 then return end
    if MC.Blackout[tonumber(src)] then return end
    D.Set(src, s.drunk - Config.Drunk.DecayPerMinute * seconds / 60)
end

---------------------------------
-- blackout
---------------------------------
function D.StartBlackout(src)
    src = tonumber(src)
    local B = Config.Drunk.Blackout
    local now = os.time()
    MC.Blackout[src] = { started = now, wakeBy = now + B.SafetySeconds }
    MC.Pending[src] = nil
    MC.Notify(src, 'blackout', 'error')
    TriggerClientEvent('MULTIconsumables:client:blackout', src)
    MC.Debug('blackout %s', src)
end

function D.Wake(src)
    src = tonumber(src)
    if not MC.Blackout[src] then return false end
    MC.Blackout[src] = nil
    local s = MC.Get(src)
    if not s then return false end
    local B = Config.Drunk.Blackout
    D.Set(src, math.min(s.drunk, B.WakeLevel))
    for key, delta in pairs(B.Hangover or {}) do
        if delta ~= 0 then pcall(function() exports.MULTIhud:AddNeed(src, key, delta) end) end
    end
    MC.Notify(src, 'wake_up', 'info')
    MC.Save(src)
    MC.Debug('woke %s', src)
    return true
end

-- the client reports that the black screen is over (not before the configured time)
RegisterNetEvent('MULTIconsumables:server:wake', function()
    local src = source
    local b = MC.Blackout[src]
    if not b then return end
    if os.time() < b.started + Config.Drunk.Blackout.BlackSeconds then return end
    D.Wake(src)
end)
