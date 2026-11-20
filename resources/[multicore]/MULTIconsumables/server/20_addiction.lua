-- ============================================================
-- MULTIconsumables :: addiction (server)
-- Per character and substance: level 0-100, time of last use, recovery and relief times
-- (os.time(), so time logged out counts for cravings and recovery). See Config.Addiction.
-- ============================================================

MC.Addiction = {}
local A = MC.Addiction

local function cfg(name) return Config.Addiction.Substances[name] end

function A.Data(s, name)
    local d = s.add[name]
    if not d then
        d = { level = 0, last = 0, relief = 0, uses = 0 }
        s.add[name] = d
    end
    return d
end

function A.IsAddicted(s, name)
    local c, d = cfg(name), s.add[name]
    return c ~= nil and d ~= nil and d.level >= c.addictedAt
end

--- 'none' (not addicted) | 'ok' | 'craving' | 'withdrawal'
function A.Status(s, name, now)
    if not Config.Addiction.Enabled or not A.IsAddicted(s, name) then return 'none' end
    local c, d = cfg(name), s.add[name]
    now = now or os.time()
    if now < (d.relief or 0) then return 'ok' end
    local since = now - (d.last or 0)
    if since >= c.withdrawalAfter then return 'withdrawal' end
    if since >= c.cravingAfter then return 'craving' end
    return 'ok'
end

--- Share of an item's good effects that still works (1.0 = all; tolerance lowers it).
function A.ToleranceMult(s, name)
    local c = cfg(name)
    if not Config.Addiction.Enabled or not c then return 1.0 end
    local d = s.add[name]
    local level = d and d.level or 0
    return math.max(0.0, 1.0 - (c.tolerance or 0) * level / 100)
end

--- What the client needs to show withdrawal: the strongest shake and a screen effect.
function A.ClientFlags(s)
    local out = { shake = 0.0, postfx = false, active = false }
    local now = os.time()
    for name, c in pairs(Config.Addiction.Substances) do
        if A.Status(s, name, now) == 'withdrawal' then
            local w = c.withdrawal or {}
            out.active = true
            if (w.shake or 0) > out.shake then out.shake = w.shake end
            if w.postfx and not out.postfx then out.postfx = w.postfx end
        end
    end
    return out
end

local function pushFlags(src, s)
    TriggerClientEvent('MULTIconsumables:client:withdrawal', src, A.ClientFlags(s))
end

--- One use of a substance.
function A.Use(src, name, amount)
    if not Config.Addiction.Enabled then return end
    local c = cfg(name)
    local s = MC.Get(src)
    if not c or not s then return end
    local now = os.time()
    local before = A.Status(s, name, now)
    local wasAddicted = A.IsAddicted(s, name)
    local d = A.Data(s, name)
    d.level = math.min(100, d.level + (tonumber(amount) or c.gainPerUse))
    d.last = now
    d.rec = nil
    d.uses = d.uses + 1
    d.notified = nil
    s.dirty = true
    if before == 'withdrawal' then MC.Notify(src, 'withdrawal_eased', 'success') end
    if not wasAddicted and A.IsAddicted(s, name) then MC.Notify(src, 'addicted', 'warning', _L('sub_' .. name)) end
    pushFlags(src, s)
    MC.Debug('addiction %s %s: %.2f (use %d)', src, name, d.level, d.uses)
end

--- Sets a substance's level. lastAgo = seconds since the last use (optional).
function A.Set(src, name, level, lastAgo)
    local c = cfg(name)
    local s = MC.Get(src)
    if not c or not s then return false end
    local d = A.Data(s, name)
    d.level = math.max(0, math.min(100, tonumber(level) or 0))
    if lastAgo then d.last = os.time() - math.floor(tonumber(lastAgo) or 0); d.rec = nil end
    s.dirty = true
    pushFlags(src, s)
    MC.Save(src)
    return true
end

--- A cure item: { substance = amount } removed; relief = seconds without cravings / withdrawal.
function A.Cure(src, cures, relief)
    local s = MC.Get(src)
    if not s or type(cures) ~= 'table' then return end
    local now = os.time()
    for name, amount in pairs(cures) do
        if cfg(name) and s.add[name] then
            local d = s.add[name]
            d.level = math.max(0, d.level - (tonumber(amount) or 0))
            if relief and relief > 0 then d.relief = math.max(d.relief or 0, now + relief) end
        end
    end
    s.dirty = true
    MC.Notify(src, 'cured', 'success')
    pushFlags(src, s)
end

--- Recovery over long abstinence (also catches up on time spent logged out).
function A.Recover(src, s, now, silent)
    for name, d in pairs(s.add) do
        local c = cfg(name)
        if c and d.level > 0 then
            local start = (d.last or 0) + c.recoverAfter
            if now > start then
                local from = math.max(d.rec or 0, start)
                local dt = now - from
                if dt > 0 then
                    local was = A.IsAddicted(s, name)
                    d.level = math.max(0, d.level - c.recoverPerHour * dt / 3600)
                    d.rec = now
                    s.dirty = true
                    if was and not A.IsAddicted(s, name) and not silent then
                        MC.Notify(src, 'recovered', 'success', _L('sub_' .. name))
                    end
                end
            end
        end
    end
end

--- Cravings and withdrawal for an online player (one addiction tick).
function A.Tick(src, s, now)
    if not Config.Addiction.Enabled then return end
    now = now or os.time()
    A.Recover(src, s, now, false)
    s.addTicks = (s.addTicks or 0) + 1
    local cores = { healthCore = 0, staminaCore = 0 }
    for name, c in pairs(Config.Addiction.Substances) do
        local d = s.add[name]
        local status = A.Status(s, name, now)
        if status == 'withdrawal' then
            local w = c.withdrawal or {}
            if (w.stress or 0) ~= 0 then pcall(function() exports.MULTIhud:AddNeed(src, 'stress', w.stress) end) end
            cores.healthCore = cores.healthCore + (w.healthCore or 0)
            cores.staminaCore = cores.staminaCore + (w.staminaCore or 0)
            if not d.notified or s.addTicks % math.max(1, Config.Addiction.NotifyEveryTicks) == 0 then
                MC.Notify(src, 'withdrawal_' .. name, 'error')
            end
            d.notified = true
        elseif status == 'craving' then
            if math.random(100) <= (c.cravingChance or 0) then MC.Notify(src, 'craving_' .. name, 'warning') end
        elseif d then
            d.notified = nil
        end
    end
    if cores.healthCore ~= 0 or cores.staminaCore ~= 0 then
        TriggerClientEvent('MULTIconsumables:client:effects', src, cores)
    end
    pushFlags(src, s)
end
