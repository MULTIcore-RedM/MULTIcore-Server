-- MULTIhud server: rsg-hud server events and exports for other resources.

---------------------------------------------------------------------------
-- rsg-hud server events (fired from RSG clients, e.g. rsg-consume:
--   TriggerServerEvent('hud:server:GainStress', amount)  -- amount may be negative)
---------------------------------------------------------------------------
if Config.Rsg.Enabled then
    local last = {}

    local function stressChange(src, delta)
        delta = tonumber(delta)
        if not delta or delta ~= delta then return end
        local now = GetGameTimer()
        if last[src] and now - last[src] < Config.ClientWrites.StressFloodMs then return end   -- flood guard
        last[src] = now
        local cap = Config.ClientWrites.MaxStressStep
        delta = math.max(-cap, math.min(cap, delta))
        local P = Needs.Player(src)
        if P then Needs.Add(P, { stress = delta }) end
    end

    RegisterNetEvent('hud:server:GainStress', function(amount)
        stressChange(source, amount)
    end)

    RegisterNetEvent('hud:server:RelieveStress', function(amount)
        stressChange(source, -(tonumber(amount) or 0))
    end)

    AddEventHandler('playerDropped', function() last[source] = nil end)
end

---------------------------------------------------------------------------
-- Exports (server)
--   exports.MULTIhud:GetNeeds(src)              -> { hunger, thirst, cleanliness, stress, metabolism } or nil
--   exports.MULTIhud:GetNeed(src, key)          -> number or nil
--   exports.MULTIhud:SetNeed(src, key, value)   -> true / false
--   exports.MULTIhud:AddNeed(src, key, delta)   -> true / false
--   exports.MULTIhud:SetNeeds(src, { hunger = 100, thirst = 100 }) -> true / false
---------------------------------------------------------------------------
exports('GetNeeds', function(src)
    local P = Needs.Player(src)
    if not P then return nil end
    local out = {}
    for key in pairs(Needs.Range) do out[key] = Needs.Get(P, key) end
    return out
end)

exports('GetNeed', function(src, key)
    local P = Needs.Player(src)
    if not P or not Needs.Range[key] then return nil end
    return Needs.Get(P, key)
end)

exports('SetNeed', function(src, key, value)
    local P = Needs.Player(src)
    if not P or not Needs.Range[key] or type(value) ~= 'number' then return false end
    Needs.Write(P, { [key] = value })
    return true
end)

exports('AddNeed', function(src, key, delta)
    local P = Needs.Player(src)
    if not P or not Needs.Range[key] or type(delta) ~= 'number' then return false end
    Needs.Add(P, { [key] = delta })
    return true
end)

exports('SetNeeds', function(src, tbl)
    local P = Needs.Player(src)
    if not P or type(tbl) ~= 'table' then return false end
    Needs.Write(P, tbl)
    return true
end)
