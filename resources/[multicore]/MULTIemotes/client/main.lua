-- ============================================================
-- MULTIemotes :: client emote player
-- Plays kit emotes, scenarios and animations on the local player,
-- stops them (cancel key / command), keeps the favourites (KVP)
-- and handles the /e and /emotecancel commands.
-- The emote and animation calls follow RSG v2 rsg-animations
-- (GPL v3, XakraD / Rexshack-RedM, see CREDITS.md).
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local N = {
    TASK_PLAY_EMOTE_WITH_HASH = 0xB31A277C1AC7B7FF, -- femga natives.json
}
local EMOTE_TYPE = 0          -- eEmoteType as rsg-animations passes it
local PM_UPPERBODY = 0        -- eEmotePlaybackMode EMOTE_PM_UPPERBODY
local PM_FULLBODY = 2         -- eEmotePlaybackMode EMOTE_PM_FULLBODY
local ANIM_TYPE_ANY = 3       -- IS_ENTITY_PLAYING_ANIM animType: any task slot

local playing = nil           -- the emote entry now playing (nil = none)

local function dbg(...) if Config.Debug then print('[MULTIemotes]', ...) end end

function MEM.Notify(msg, kind)
    exports.MULTIcore:Notify({ text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function onMountOrVehicle(ped)
    return IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
end

--- Why the player can't play an emote now (locale key), or nil.
local function blocked(ped)
    if Config.BlockWhenDead and (IsEntityDead(ped) or IsPedDeadOrDying(ped, true)) then return 'err_blocked' end
    if Config.BlockWhenSwimming and IsPedSwimming(ped) then return 'err_blocked' end
    if Config.BlockWhenFalling and (IsPedFalling(ped) or IsPedRagdoll(ped)) then return 'err_blocked' end
    return nil
end

local function loadDict(dict)
    RequestAnimDict(dict)
    for _ = 1, Config.AnimLoadTries do
        if HasAnimDictLoaded(dict) then return true end
        Wait(Config.AnimLoadWaitMs)
    end
    return HasAnimDictLoaded(dict)
end

--- Stops whatever emote is playing.
function MEM.Stop()
    local ped = cache.ped
    if playing and playing.kind == 'emote' and playing.upper then
        ClearPedSecondaryTask(ped)
    else
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)
    end
    dbg('stop', playing and playing.id)
    if playing then MEM.StoppedAt = GetGameTimer() end -- client/gestures.lua: the X that stopped it doesn't also raise the hands
    playing = nil
end

--- Plays emote entry `e` (from config/emotes.lua). `body` = 'full' | 'upper' | nil (auto).
--- Returns true, or false and a locale key.
function MEM.Play(e, body)
    if type(e) ~= 'table' or not e.kind then return false, 'err_unknown' end
    local ped = cache.ped
    local why = blocked(ped)
    if why then return false, why end

    local mounted = onMountOrVehicle(ped)
    local upper = body == 'upper'
    if mounted then
        if e.kind ~= 'emote' or not Config.UpperBodyOnMount then return false, 'err_mounted' end
        upper = true
    end

    if e.kind == 'emote' then
        if upper then
            ClearPedSecondaryTask(ped)
            Citizen.InvokeNative(N.TASK_PLAY_EMOTE_WITH_HASH, ped, EMOTE_TYPE, PM_UPPERBODY, joaat(e.emote), true, true, false, false, false)
        else
            ClearPedTasks(ped)
            Citizen.InvokeNative(N.TASK_PLAY_EMOTE_WITH_HASH, ped, EMOTE_TYPE, PM_FULLBODY, joaat(e.emote), false, false, false, false, false)
        end
    elseif e.kind == 'scenario' then
        ClearPedTasks(ped)
        TaskStartScenarioInPlaceHash(ped, joaat(e.scenario), -1, true, 0, GetEntityHeading(ped), false) -- TASK_START_SCENARIO_IN_PLACE_HASH, facing where the player faces
    else
        if not loadDict(e.dict) then return false, 'err_failed' end
        ClearPedTasks(ped)
        -- argument pattern as rsg-animations: playbackRate 1, taskFilter 0, p12 true
        TaskPlayAnim(ped, e.dict, e.clip, Config.AnimBlendIn, Config.AnimBlendOut, -1, e.flag or 1, 1, false, false, false, 0, true)
        RemoveAnimDict(e.dict)
    end
    playing = { id = e.id, kind = e.kind, upper = upper, dict = e.dict, clip = e.clip, since = GetGameTimer() }
    dbg('play', e.id, e.kind, upper and 'upper' or 'full')
    return true
end

--- Plays by id or label and tells the player when it can't.
function MEM.PlayByName(text, body)
    local e = MEM.FindEmote(text)
    if not e then
        MEM.Notify(_L('err_unknown', tostring(text)), 'error')
        return false
    end
    local ok, why = MEM.Play(e, body)
    if not ok then MEM.Notify(_L(why), 'error') end
    return ok
end

function MEM.IsPlaying() return playing ~= nil end

---------------------------------
-- favourites (KVP on the player's PC)
---------------------------------
function MEM.GetFavourites()
    local raw = GetResourceKvpString(Config.FavouritesKvp)
    local ok, list = pcall(json.decode, raw or '[]')
    local out = {}
    if ok and type(list) == 'table' then
        for _, id in ipairs(list) do
            if MEM.EmoteById[id] then out[#out + 1] = id end
        end
    end
    return out
end

--- Adds or removes a favourite. Returns the new list.
function MEM.SetFavourite(id, on)
    local list = MEM.GetFavourites()
    if not MEM.EmoteById[id] then return list end
    local at
    for i, v in ipairs(list) do if v == id then at = i break end end
    if on and not at and #list < Config.MaxFavourites then
        list[#list + 1] = id
    elseif not on and at then
        table.remove(list, at)
    end
    SetResourceKvp(Config.FavouritesKvp, json.encode(list))
    return list
end

---------------------------------
-- cancel key: watched only while an emote plays
---------------------------------
local lastCheck = 0
--- false once the current emote is over (checked every Config.PlayingCheckMs, after a grace time).
local function stillPlaying()
    local now = GetGameTimer()
    if now - playing.since < Config.PlayingGraceMs or now - lastCheck < Config.PlayingCheckMs then return true end
    lastCheck = now
    local ped = cache.ped
    if playing.kind == 'scenario' then return IsPedUsingAnyScenario(ped) end
    if playing.kind == 'anim' then return IsEntityPlayingAnim(ped, playing.dict, playing.clip, ANIM_TYPE_ANY) end
    return now - playing.since < Config.EmoteWatchMs -- kit emotes play once and end by themselves
end

CreateThread(function()
    while true do
        if playing then
            Wait(0)
            local key = Config.CancelKey ~= '' and RSGCore.Shared.Keybinds[Config.CancelKey] or nil
            if key and (IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)) and not IsNuiFocused() then
                MEM.Stop()
            elseif IsEntityDead(cache.ped) then
                playing = nil
            elseif not stillPlaying() then
                playing = nil -- ended by itself (or the player walked out of it): stop watching the key
            end
        else
            Wait(500)
        end
    end
end)

---------------------------------
-- commands
---------------------------------
if Config.Commands.Emote ~= '' then
    RegisterCommand(Config.Commands.Emote, function(_, args)
        if not args[1] then return MEM.OpenMenu() end
        MEM.PlayByName(table.concat(args, ' '))
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Emote, _L('help_e'), { { name = 'name', help = _L('help_e_name') } })
end
if Config.Commands.Cancel ~= '' then
    RegisterCommand(Config.Commands.Cancel, function() MEM.Stop() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Cancel, _L('help_cancel'))
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and playing then MEM.Stop() end
end)
