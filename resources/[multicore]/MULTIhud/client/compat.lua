-- MULTIhud client: answers the events VORP and RSG food / drink / medic scripts send to their HUD.
-- Every change goes to the server, which stores it in the RSGCore metadata and the state bag.

local function setNeeds(t) TriggerServerEvent('MULTIhud:server:setNeeds', t) end
local function addNeeds(t) TriggerServerEvent('MULTIhud:server:addNeeds', t) end

---------------------------------------------------------------------------
-- vorp_metabolism stand-in
-- From docs.vorp-core.com (vorp_metabolism page), client events:
--   vorpmetabolism:changeValue (status, amount)  adds amount, clamped
--   vorpmetabolism:setValue    (status, value)   sets value, clamped
--   vorpmetabolism:getValue    (status, cb)      cb(value) or cb(nil) for an unknown status
--   vorpmetabolism:setHud      (visible)
-- Status names (case insensitive): Metabolism (-10000..10000), Thirst (0..1000), Hunger (0..1000).
-- The docs list no exports.
---------------------------------------------------------------------------
if Config.Vorp.Enabled then
    local SCALE = Config.Vorp.Scale

    -- documented statuses -> metadata key and scale
    local NEEDS = {
        hunger = { key = 'hunger', scale = SCALE },
        thirst = { key = 'thirst', scale = SCALE },
        metabolism = { key = 'metabolism', scale = 1 },
    }

    -- ASSUMPTION (not in the docs): VORP item configs also name the game cores; these are applied
    -- straight to the player's ped. Cores use the game's 0-100 scale, outer health / stamina raw points.
    local function applyCore(name, amount, absolute)
        local ped = PlayerPedId()
        if name == 'innercorehealth' or name == 'innercorestamina' then
            local core = name == 'innercorehealth' and HudCore.HEALTH or HudCore.STAMINA
            local v = absolute and amount or (Hud.Core(ped, core) + amount)
            Citizen.InvokeNative(HudN.SET_ATTRIBUTE_CORE_VALUE, ped, core, math.floor(math.max(0, math.min(HudCore.MAX, v))))
            return true
        elseif name == 'outercorehealth' then
            local max = GetEntityMaxHealth(ped, false)
            local v = absolute and amount or (GetEntityHealth(ped) + amount)
            SetEntityHealth(ped, math.floor(math.max(1, math.min(max, v))), 0)
            return true
        elseif name == 'outercorestamina' or name == 'stamina' then
            if absolute then
                local max = Citizen.InvokeNative(HudN.GET_PED_MAX_STAMINA, ped, Citizen.ResultAsFloat())
                local cur = Citizen.InvokeNative(HudN.GET_PED_STAMINA, ped, Citizen.ResultAsFloat())
                amount = math.min(amount, max) - cur
            end
            Citizen.InvokeNative(HudN.CHANGE_PED_STAMINA, ped, amount + 0.0)
            return true
        end
        return false
    end

    local function handle(status, amount, absolute)
        if type(status) ~= 'string' then return end
        amount = tonumber(amount)
        if not amount then return end
        local name = status:lower()
        local n = NEEDS[name]
        if n then
            if absolute then
                setNeeds({ [n.key] = amount / n.scale })
            else
                addNeeds({ [n.key] = amount / n.scale })
            end
            return
        end
        applyCore(name, amount, absolute)
    end

    RegisterNetEvent('vorpmetabolism:changeValue', function(status, amount)
        handle(status, amount, false)
    end)

    RegisterNetEvent('vorpmetabolism:setValue', function(status, value)
        handle(status, value, true)
    end)

    -- local only: a callback can't cross the network
    AddEventHandler('vorpmetabolism:getValue', function(status, cb)
        if type(cb) ~= 'function' and type(cb) ~= 'table' then return end
        local n = type(status) == 'string' and NEEDS[status:lower()]
        if not n then cb(nil) return end
        cb((tonumber(LocalPlayer.state[n.key]) or Config.Defaults[n.key] or 0) * n.scale)
    end)

    RegisterNetEvent('vorpmetabolism:setHud', function(visible)
        Hud.scriptOn = visible and true or false
    end)
end

---------------------------------------------------------------------------
-- rsg-hud client events, as RSG v2 scripts fire them:
--   rsg-consume  hud:client:UpdateHunger(value), hud:client:UpdateThirst(value),
--                hud:client:RelieveStress(amount)
--   rsg-canteen / rsg-essentials  hud:client:UpdateThirst(value)
--   rsg-bathing / rsg-essentials  hud:client:UpdateCleanliness(value)
--   rsg-medic    hud:client:UpdateNeeds(hunger, thirst, cleanliness), hud:client:UpdateStress(value)
-- Update* values are absolute (0-100); RelieveStress / GainStress are amounts.
---------------------------------------------------------------------------
if Config.Rsg.Enabled then
    RegisterNetEvent('hud:client:UpdateHunger', function(v)
        if type(v) == 'number' then setNeeds({ hunger = v }) end
    end)

    RegisterNetEvent('hud:client:UpdateThirst', function(v)
        if type(v) == 'number' then setNeeds({ thirst = v }) end
    end)

    RegisterNetEvent('hud:client:UpdateCleanliness', function(v)
        if type(v) == 'number' then setNeeds({ cleanliness = v }) end
    end)

    RegisterNetEvent('hud:client:UpdateStress', function(v)
        if type(v) == 'number' then setNeeds({ stress = v }) end
    end)

    RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst, cleanliness)
        local t = {}
        if type(hunger) == 'number' then t.hunger = hunger end
        if type(thirst) == 'number' then t.thirst = thirst end
        if type(cleanliness) == 'number' then t.cleanliness = cleanliness end
        if next(t) then setNeeds(t) end
    end)

    RegisterNetEvent('hud:client:RelieveStress', function(amount)
        amount = tonumber(amount)
        if amount then addNeeds({ stress = -math.abs(amount) }) end
    end)

    RegisterNetEvent('hud:client:GainStress', function(amount)
        amount = tonumber(amount)
        if amount then addNeeds({ stress = math.abs(amount) }) end
    end)
end

---------------------------------------------------------------------------
-- client exports
--   exports.MULTIhud:GetNeeds() -> { hunger, thirst, cleanliness, stress } (0-100)
--   exports.MULTIhud:SetVisible(bool)  -- hide / show the HUD from another script (e.g. a menu)
--   exports.MULTIhud:ShowMoney(seconds)
---------------------------------------------------------------------------
exports('GetNeeds', function()
    local st = LocalPlayer.state
    return {
        hunger = tonumber(st.hunger) or 0,
        thirst = tonumber(st.thirst) or 0,
        cleanliness = tonumber(st.cleanliness) or 0,
        stress = tonumber(st.stress) or 0,
    }
end)

exports('SetVisible', function(visible)
    Hud.scriptOn = visible and true or false
end)

exports('ShowMoney', function(seconds)
    Hud.moneyUntil = GetGameTimer() + (tonumber(seconds) or Config.Money.ShowSeconds) * 1000
end)
