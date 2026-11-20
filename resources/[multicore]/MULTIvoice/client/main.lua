-- ============================================================
-- MULTIvoice :: client
-- Proximity voice: what this player says goes only to players within
-- the chosen range (sending range), heard in 3D. Radio and call
-- members are added on top. Players in another routing bucket are
-- never in range, so they never hear each other.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local TARGET = 1                         -- the voice target id this script uses
local PUSH_TO_TALK = 0x4BC9DABB          -- the game's push-to-talk control (N)
local SET_CONTROL_VALUE_NEXT_FRAME = 0xE8A25867FBA3B05E

local rangeIndex = math.max(1, math.min(#Config.Ranges, Config.DefaultRange or 1))
local override = nil                     -- { distance, noCycle } from overrideProximityRange
local radio = { ch = 0, members = {}, talking = false, volume = Config.Radio.Volume, enabled = true }
local call = { ch = 0, members = {}, volume = Config.Call.Volume }
local voiceOn = true                     -- setVoiceProperty('voiceEnabled', false) mutes this player

local function notify(text)
    if Config.Notify then exports.MULTIcore:Notify({ text = text, type = 'info', duration = 2000 }) end
end

local function distance()
    if override then return override.distance end
    return Config.Ranges[rangeIndex].distance
end

--- Shares the range on the player's state bag (the HUD and other scripts read it).
local function publishRange()
    local r = Config.Ranges[rangeIndex]
    LocalPlayer.state:set('proximity', {
        index = rangeIndex,
        distance = distance(),
        mode = override and _L('range_custom') or _L(r.label),
    }, true)
    MumbleSetTalkerProximity(distance() + 0.0)
end

local function setRange(i, quiet)
    if override and override.noCycle then return end
    rangeIndex = ((i - 1) % #Config.Ranges) + 1
    publishRange()
    if not quiet then
        notify(_L('range_now', _L(Config.Ranges[rangeIndex].label), ('%g'):format(Config.Ranges[rangeIndex].distance)))
    end
end

-- ---------------------------------------------------------------
-- who hears this player (rebuilt every Config.UpdateMs)
-- ---------------------------------------------------------------

local function rebuildTargets()
    MumbleClearVoiceTargetPlayers(TARGET)
    if not voiceOn then return end
    local added = {}
    local function add(serverId)
        if serverId and serverId > 0 and not added[serverId] then
            added[serverId] = true
            MumbleAddVoiceTargetPlayerByServerId(TARGET, serverId)
        end
    end

    local me = PlayerId()
    local here = GetEntityCoords(PlayerPedId())
    local range = distance()
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and #(here - GetEntityCoords(ped)) <= range then add(GetPlayerServerId(player)) end
        end
    end

    for _, id in ipairs(call.members) do add(id) end
    if radio.talking then
        for _, id in ipairs(radio.members) do add(id) end
    end
end

CreateThread(function()
    while not MumbleIsConnected() do Wait(500) end
    MumbleSetVoiceTarget(TARGET)
    publishRange()
    while true do
        rebuildTargets()
        Wait(Config.UpdateMs)
    end
end)

-- ---------------------------------------------------------------
-- keys
-- ---------------------------------------------------------------

local function pressed(key)
    return IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)
end

local function held(key)
    return IsControlPressed(0, key) or IsDisabledControlPressed(0, key)
end

local function setRadioTalking(on)
    if radio.talking == on then return end
    radio.talking = on
    LocalPlayer.state:set('radioActive', on, true)
    TriggerServerEvent('MULTIvoice:radioTalk', on)
    rebuildTargets()
end

CreateThread(function()
    while true do
        local wait = 250
        if Config.CycleKey then
            wait = 0
            if pressed(Config.CycleKey) and not IsPauseMenuActive() then setRange(rangeIndex + 1) end
        end
        if Config.Radio.Enabled and radio.ch > 0 and radio.enabled and Config.Radio.Key then
            wait = 0
            local down = held(Config.Radio.Key) and not IsPauseMenuActive()
            if down then
                -- open the microphone while the radio key is held
                Citizen.InvokeNative(SET_CONTROL_VALUE_NEXT_FRAME, 0, PUSH_TO_TALK, 1.0)
            end
            setRadioTalking(down)
        elseif radio.talking then
            setRadioTalking(false)
        end
        Wait(wait)
    end
end)

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, function(_, args)
        local n = tonumber(args[1])
        if n and Config.Ranges[n] then setRange(n) else setRange(rangeIndex + 1) end
    end, false)
end

-- ---------------------------------------------------------------
-- radio and call members (from the server)
-- ---------------------------------------------------------------

local function setVolume(list, vol)
    for _, id in ipairs(list) do MumbleSetVolumeOverrideByServerId(id, vol) end
end

RegisterNetEvent('MULTIvoice:members', function(kind, ch, list)
    local me = GetPlayerServerId(PlayerId())
    local others = {}
    for _, id in ipairs(list or {}) do if id ~= me then others[#others + 1] = id end end

    if kind == 'call' then
        setVolume(call.members, -1.0)
        call.ch, call.members = ch, others
        -- a call is heard at the same loudness however far away the other side is
        setVolume(call.members, call.volume)
    elseif kind == 'radio' then
        setVolume(radio.members, -1.0)
        radio.ch, radio.members = ch, others
        if ch == 0 then setRadioTalking(false) end
    end
    rebuildTargets()
end)

-- someone on the radio channel presses or lets go of the radio key
RegisterNetEvent('MULTIvoice:radioTalking', function(serverId, talking)
    MumbleSetVolumeOverrideByServerId(serverId, talking and radio.volume or -1.0)
end)

-- ---------------------------------------------------------------
-- exports (also answered as exports['pma-voice'])
-- ---------------------------------------------------------------

local API = {}

function API.setRadioChannel(ch) TriggerServerEvent('MULTIvoice:join', 'radio', tonumber(ch) or 0) end
function API.addPlayerToRadio(ch) API.setRadioChannel(ch) end
function API.removePlayerFromRadio() API.setRadioChannel(0) end
function API.setCallChannel(ch) TriggerServerEvent('MULTIvoice:join', 'call', tonumber(ch) or 0) end
function API.addPlayerToCall(ch) API.setCallChannel(ch) end
function API.removePlayerFromCall() API.setCallChannel(0) end

--- Volume 0 - 100 (pma-voice) or 0.0 - 1.0.
local function vol(v)
    v = tonumber(v) or 0
    if v > 1 then v = v / 100 end
    return math.max(0.0, math.min(1.0, v))
end

function API.setRadioVolume(v) radio.volume = vol(v) end
function API.setCallVolume(v)
    call.volume = vol(v)
    setVolume(call.members, call.volume)
end

function API.setVoiceProperty(prop, value)
    if prop == 'radioEnabled' then
        radio.enabled = value == true
        if not radio.enabled then setRadioTalking(false) end
    elseif prop == 'voiceEnabled' then
        voiceOn = value ~= false
        rebuildTargets()
    end
end

--- Forces a range (e.g. a megaphone). noCycle = true blocks the range key until cleared.
function API.overrideProximityRange(range, noCycle)
    range = tonumber(range)
    if not range then return end
    override = { distance = range + 0.0, noCycle = noCycle == true }
    publishRange()
end

function API.clearProximityOverride()
    override = nil
    publishRange()
end

function API.getRange() return distance() end
function API.getRangeIndex() return rangeIndex end
function API.setRange(i) if Config.Ranges[tonumber(i) or 0] then setRange(tonumber(i), true) end end

for name, fn in pairs(API) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_pma-voice_%s'):format(name), function(setCB) setCB(fn) end)
end
