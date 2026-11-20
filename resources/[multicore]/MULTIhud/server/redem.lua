-- ============================================================
-- MULTIhud :: redemrp_status face (server)
-- RedEM:RP scripts change hunger, thirst and stress through these
-- events. The values live in the same character metadata (0-100), so
-- every framework's scripts see the same needs.
-- Written from RedEM:RP's public API; no RedEM:RP code is used.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local last = {}

--- Client writes are limited like the rsg-hud events (flood guard, step cap).
local function fromClient(src)
    local now = GetGameTimer()
    if last[src] and now - last[src] < Config.ClientWrites.StressFloodMs then return false end
    last[src] = now
    return true
end

local function clampStep(n)
    n = tonumber(n) or 0
    if n ~= n then return 0 end
    local cap = Config.ClientWrites.MaxStressStep
    return math.max(-cap, math.min(cap, n))
end

local function add(src, deltas)
    local P = Needs.Player(src)
    if P then Needs.Add(P, deltas) end
end

-- client: TriggerServerEvent('redemrp_status:server:AddHungerThirst', hunger, thirst)
RegisterNetEvent('redemrp_status:server:AddHungerThirst', function(hunger, thirst)
    local src = source
    if not fromClient(src) then return end
    add(src, { hunger = clampStep(hunger), thirst = clampStep(thirst) })
end)

-- server: TriggerEvent('redemrp_status:server:AddHungerThirstForId', src, hunger, thirst)
AddEventHandler('redemrp_status:server:AddHungerThirstForId', function(src, hunger, thirst)
    add(tonumber(src), { hunger = tonumber(hunger) or 0, thirst = tonumber(thirst) or 0 })
end)

for _, name in ipairs({ 'redemrp_status:server:AddStress', 'redemrp_status:AddStress' }) do
    RegisterNetEvent(name, function(amount)
        local src = tonumber(source)
        if not src or src <= 0 or not fromClient(src) then return end
        add(src, { stress = clampStep(amount) })
    end)
end

for _, name in ipairs({ 'redemrp_status:server:RelieveStress', 'redemrp_status:RelieveStress' }) do
    RegisterNetEvent(name, function(amount)
        local src = tonumber(source)
        if not src or src <= 0 or not fromClient(src) then return end
        add(src, { stress = -clampStep(amount) })
    end)
end

-- server: TriggerEvent('redemrp_status:server:FeedMe', src)
AddEventHandler('redemrp_status:server:FeedMe', function(src)
    local P = Needs.Player(tonumber(src))
    if P then Needs.Write(P, { hunger = 100, thirst = 100 }) end
end)

AddEventHandler('playerDropped', function() last[source] = nil end)

-- RedEM:RP HUD scripts listen for redemrp_status:UpdateStatus (thirst, hunger, stress)
CreateThread(function()
    while true do
        Wait(30000)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local P = Needs.Player(src)
            if P then
                TriggerClientEvent('redemrp_status:UpdateStatus', src,
                    Needs.Get(P, 'thirst'), Needs.Get(P, 'hunger'), Needs.Get(P, 'stress'))
            end
        end
    end
end)
