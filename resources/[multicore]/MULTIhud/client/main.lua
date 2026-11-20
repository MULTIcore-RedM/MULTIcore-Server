-- MULTIhud client: reads the game and the player's needs, drives the NUI HUD.
-- Natives checked against femga natives.json. Natives whose name starts with "_" have no
-- official Lua name, so they are called by hash.

local RSGCore = exports['rsg-core']:GetCoreObject()

-- natives called by hash (all present in femga natives.json)
HudN = {
    GET_PED_STAMINA = 0x775A1CA7893AA8B5,          -- _GET_PED_STAMINA(ped) -> float
    GET_PED_MAX_STAMINA = 0xCB42AFE2B613EE55,      -- _GET_PED_MAX_STAMINA(ped) -> float
    CHANGE_PED_STAMINA = 0xC3D4B754C0E86B9E,       -- _CHANGE_PED_STAMINA(ped, amount)
    GET_ATTRIBUTE_CORE_VALUE = 0x36731AC041289BB1, -- _GET_ATTRIBUTE_CORE_VALUE(ped, core) -> int 0-100
    SET_ATTRIBUTE_CORE_VALUE = 0xC6258F41D86676E0, -- _SET_ATTRIBUTE_CORE_VALUE(ped, core, value)
    GET_TEMPERATURE_AT_COORDS = 0xB98B78C3768AF6E0,-- _GET_TEMPERATURE_AT_COORDS(x, y, z) -> float
    SHOULD_USE_METRIC_TEMPERATURE = 0xFF4AAF3275BAAB4F, -- _SHOULD_USE_METRIC_TEMPERATURE() -> BOOL
}
HudCore = { HEALTH = 0, STAMINA = 1, DEADEYE = 2, MAX = 100 }  -- eAttributeCore (natives.json comment); cores run 0-100

Hud = {
    userOn = true,          -- /hud toggle (saved in KVP)
    scriptOn = true,        -- vorpmetabolism:setHud
    loggedIn = false,
    money = { cash = 0, bank = 0, gold = 0, bloodmoney = 0 },
    moneyUntil = 0,         -- GetGameTimer() until which the money panel stays
    temp = nil,             -- last world temperature, degrees C
}

local function nui(msg) SendNUIMessage(msg) end

local function pct(cur, max)
    if not cur or not max or max <= 0 then return 0 end
    local p = cur / max * 100
    if p < 0 then p = 0 elseif p > 100 then p = 100 end
    return math.floor(p + 0.5)
end

function Hud.Stamina(ped)
    local cur = Citizen.InvokeNative(HudN.GET_PED_STAMINA, ped, Citizen.ResultAsFloat())
    local max = Citizen.InvokeNative(HudN.GET_PED_MAX_STAMINA, ped, Citizen.ResultAsFloat())
    return pct(cur, max)
end

function Hud.Core(ped, core)
    return Citizen.InvokeNative(HudN.GET_ATTRIBUTE_CORE_VALUE, ped, core, Citizen.ResultAsInteger()) or 0
end

function Hud.Health(ped)
    return pct(GetEntityHealth(ped), GetEntityMaxHealth(ped, false))
end

-- world temperature at the player, degrees C (unit UNVERIFIED: natives.json gives no unit;
-- the game's own HUD shows C or F from the same world value depending on _SHOULD_USE_METRIC_TEMPERATURE)
function Hud.Temperature(ped)
    local c = GetEntityCoords(ped)
    return Citizen.InvokeNative(HudN.GET_TEMPERATURE_AT_COORDS, c.x, c.y, c.z, Citizen.ResultAsFloat())
end

local function useCelsius()
    local u = Config.Temperature.Unit
    if u == 'C' then return true end
    if u == 'F' then return false end
    return Citizen.InvokeNative(HudN.SHOULD_USE_METRIC_TEMPERATURE, Citizen.ResultAsInteger()) == 1
end

local function shouldShow()
    if Hud.editing then return true end
    if not Hud.loggedIn or not Hud.userOn or not Hud.scriptOn then return false end
    if IsPauseMenuActive() or IsScreenFadedOut() or IsHudHidden() then return false end
    if NetworkIsInMpCutscene() or GetIsLoadingScreenActive() then return false end
    return true
end

---------------------------------------------------------------------------
-- player data (money)
---------------------------------------------------------------------------
local function readMoney(pd)
    if type(pd) ~= 'table' or type(pd.money) ~= 'table' then return end
    local m = pd.money
    Hud.money = { cash = m.cash or 0, bank = m.bank or 0, gold = m.gold or 0, bloodmoney = m.bloodmoney or 0 }
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Hud.loggedIn = true
    readMoney(RSGCore.Functions.GetPlayerData())
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    Hud.loggedIn = false
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(pd)
    readMoney(pd)
end)

-- RSG cores fire this when money changes: (type, amount, isMinus)
RegisterNetEvent('hud:client:OnMoneyChange', function()
    if Config.Money.ShowOnChange then
        Hud.moneyUntil = GetGameTimer() + Config.Money.ShowSeconds * 1000
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- resource restarted while playing
    if LocalPlayer.state.isLoggedIn then
        Hud.loggedIn = true
        readMoney(RSGCore.Functions.GetPlayerData())
    end
end)

---------------------------------------------------------------------------
-- NUI config + /hud toggle
---------------------------------------------------------------------------
local lastSent = ''
local forceVisible = false

-- the player's own HUD place and size (/hudedit), kept on their PC: { x = % from left, y = % from top, scale }
local LAYOUT_KVP = 'multihud_layout'
local function loadLayout()
    local raw = GetResourceKvpString(LAYOUT_KVP)
    local ok, l = pcall(json.decode, raw or '')
    if not ok or type(l) ~= 'table' then return nil end
    local x, y, s = tonumber(l.x), tonumber(l.y), tonumber(l.scale)
    if not x or not y or not s then return nil end
    return { x = x, y = y, scale = s }
end
Hud.layout = loadLayout()

local function sendConfig()
    nui({
        layout = Hud.layout or false,
        minScale = Config.Hud.MinScale or 0.5,
        maxScale = Config.Hud.MaxScale or 2.0,
        action = 'config',
        style = Config.Hud.Style,
        position = Config.Hud.Position,
        offsetX = Config.Hud.OffsetX,
        offsetY = Config.Hud.OffsetY,
        scale = Config.Hud.Scale,
        numbers = Config.Hud.ShowNumbers,
        low = Config.Hud.LowWarning,
        order = Config.Hud.Order,
        show = Config.Hud.Show,
        size = Config.Hud.GaugeSize,
        gap = Config.Hud.Gap,
        colors = Config.Hud.Colors,
        locale = _LT(),
        cyrillic = _LCode() == 'ru',
        money = {
            gold = Config.Money.ShowGold, bank = Config.Money.ShowBank, bloodmoney = Config.Money.ShowBloodmoney,
        },
    })
    -- the page was (re)built: send everything again
    lastSent = ''
    forceVisible = true
end

-- the page tells us when it has loaded, so the config is never sent too early
RegisterNUICallback('ready', function(_, cb)
    sendConfig()
    cb('ok')
end)

Hud.userOn = GetResourceKvpInt('multihud_off') ~= 1

RegisterCommand(Config.Hud.Command, function()
    Hud.userOn = not Hud.userOn
    SetResourceKvpInt('multihud_off', Hud.userOn and 0 or 1)
    if Config.Hud.NotifyToggle then
        exports.MULTIcore:Notify(_L(Hud.userOn and 'hud_shown' or 'hud_hidden'), 'info')
    end
end, false)

-- /hudedit: drag the HUD with the mouse, wheel = size, then Save / Reset / Cancel on the page
local function clampLayout(l)
    if type(l) ~= 'table' then return nil end
    local x, y, s = tonumber(l.x), tonumber(l.y), tonumber(l.scale)
    if not x or not y or not s then return nil end
    local lo, hi = Config.Hud.MinScale or 0.5, Config.Hud.MaxScale or 2.0
    return { x = math.max(0, math.min(100, x)), y = math.max(0, math.min(100, y)), scale = math.max(lo, math.min(hi, s)) }
end

local function stopEdit()
    Hud.editing = false
    SetNuiFocus(false, false)
    nui({ action = 'edit', on = false })
end

if Config.Hud.EditCommand then
    RegisterCommand(Config.Hud.EditCommand, function()
        if Hud.editing or not Hud.loggedIn then return end
        Hud.editing = true
        forceVisible = true
        SetNuiFocus(true, true)
        nui({ action = 'edit', on = true })
    end, false)
end

if Config.Hud.ResetCommand then
    RegisterCommand(Config.Hud.ResetCommand, function()
        Hud.layout = nil
        DeleteResourceKvp(LAYOUT_KVP)
        sendConfig()
        exports.MULTIcore:Notify(_L('hud_reset'), 'info')
    end, false)
end

RegisterNUICallback('editDone', function(data, cb)
    cb('ok')
    if not Hud.editing then return end
    data = type(data) == 'table' and data or {}
    if data.reset then
        Hud.layout = nil
        DeleteResourceKvp(LAYOUT_KVP)
        exports.MULTIcore:Notify(_L('hud_reset'), 'info')
    elseif data.save then
        local l = clampLayout(data.layout)
        if l then
            Hud.layout = l
            SetResourceKvp(LAYOUT_KVP, json.encode(l))
            exports.MULTIcore:Notify(_L('hud_saved'), 'success')
        end
    end
    stopEdit()
    sendConfig()   -- back to the saved (or default) place
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and Hud.editing then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------------
-- main loop
---------------------------------------------------------------------------
local voiceRunning = false

CreateThread(function()
    while true do
        voiceRunning = Config.Hud.Show.voice and GetResourceState('pma-voice') == 'started'
        Wait(Config.Hud.VoiceCheckMs)
    end
end)

local function moneyVisible(now)
    local mode = Config.Money.Mode
    if mode == 'off' then return false end
    if mode == 'always' then return true end
    if IsControlPressed(0, Config.Money.Key) or IsDisabledControlPressed(0, Config.Money.Key) then
        Hud.moneyUntil = now + Config.Money.ShowSeconds * 1000
    end
    return now < Hud.moneyUntil
end

CreateThread(function()
    local visible = nil
    while true do
        local show = shouldShow()
        if show ~= visible or forceVisible then
            visible = show
            forceVisible = false
            nui({ action = 'visible', show = show })
        end

        if show then
            local ped = PlayerPedId()
            local now = GetGameTimer()
            local st = LocalPlayer.state
            local d = {
                health = Hud.Health(ped),
                healthCore = Hud.Core(ped, HudCore.HEALTH),
                stamina = Hud.Stamina(ped),
                staminaCore = Hud.Core(ped, HudCore.STAMINA),
                hunger = math.floor((tonumber(st.hunger) or 0) + 0.5),
                thirst = math.floor((tonumber(st.thirst) or 0) + 0.5),
                stress = math.floor((tonumber(st.stress) or 0) + 0.5),
                cleanliness = math.floor((tonumber(st.cleanliness) or 0) + 0.5),
            }

            if Config.Temperature.Enabled and Config.Hud.Show.temperature then
                local c = Hud.temp
                if c then
                    local celsius = useCelsius()
                    d.temp = celsius and math.floor(c + 0.5) or math.floor(c * 9 / 5 + 32 + 0.5)
                    d.tempUnit = celsius and 'C' or 'F'
                    d.tempBand = (c <= Config.Temperature.Cold and 'cold') or (c >= Config.Temperature.Hot and 'hot') or 'mild'
                end
            end

            if Config.Hud.Show.horse and IsPedOnMount(ped) then
                local horse = GetMount(ped)
                if horse and horse ~= 0 then
                    d.horse = {
                        health = Hud.Health(horse),
                        healthCore = Hud.Core(horse, HudCore.HEALTH),
                        stamina = Hud.Stamina(horse),
                        staminaCore = Hud.Core(horse, HudCore.STAMINA),
                    }
                end
            end

            if voiceRunning then
                local prox = st.proximity
                local talking = MumbleIsPlayerTalking(PlayerId())
                d.voice = {
                    talking = talking == true or talking == 1,
                    mode = type(prox) == 'table' and prox.mode or nil,
                    radio = st.radioActive == true,
                }
            end

            if moneyVisible(now) then
                d.money = Hud.money
            end

            local key = json.encode(d)
            if key ~= lastSent then
                lastSent = key
                nui({ action = 'update', data = d })
            end
        end

        Wait(Config.Hud.UpdateMs)
    end
end)

-- temperature changes slowly; read it every few seconds
CreateThread(function()
    while true do
        if Hud.loggedIn and Config.Temperature.Enabled then
            Hud.temp = Hud.Temperature(PlayerPedId())
        end
        Wait(Config.Temperature.ReadMs)
    end
end)

-- ---------------------------------------------------------------
-- the game's own core icons (Config.HideGameCores)
-- _UITUTORIAL_SET_RPG_ICON_VISIBILITY 0xC116E6DF68DCE667 (femga natives.json):
-- icons 0..11 = stamina, stamina core, dead eye, dead eye core, health, health core,
-- horse health, horse health core, horse stamina, horse stamina core, horse courage, horse courage core;
-- visibility 0 = normal (show, then hide), 2 = always hide. The game turns them back on now and then,
-- so this runs every few seconds.
-- ---------------------------------------------------------------
local function setGameCores(visibility)
    for icon = 0, 11 do Citizen.InvokeNative(0xC116E6DF68DCE667, icon, visibility) end
end
CreateThread(function()
    while true do
        if Config.HideGameCores then setGameCores(2) end
        Wait(3000)
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and Config.HideGameCores then setGameCores(0) end
end)
