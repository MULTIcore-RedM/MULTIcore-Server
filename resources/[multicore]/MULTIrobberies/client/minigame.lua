-- ============================================================
-- MULTIrobberies :: minigames (client)
-- The pin lock and the safe dial (html/). Both block the calling thread and return true / false.
--   exports.MULTIrobberies:Lockpick(level, label)   level = a key of Config.Minigames.Lockpick ('easy', 'medium', 'hard')
--   exports.MULTIrobberies:SafeCrack(level, label)  level = a key of Config.Minigames.Safe
-- With Config.Minigames.Enabled = false both fall back to an ox_lib skill check.
-- MULTIdoors uses Lockpick for its lockpickable doors when this script runs.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local open = false
local result = nil

local TEXT_KEYS = {
    'lock_title', 'lock_help', 'lock_state', 'lock_open', 'lock_snapped',
    'safe_title', 'safe_help', 'safe_left', 'safe_right', 'safe_reset', 'safe_open',
    'timeout', 'gave_up',
}

local function texts()
    local t = {}
    for _, k in ipairs(TEXT_KEYS) do t[k] = _L(k) end
    return t
end

local function play(game, opts, label)
    if open then return false end
    open, result = true, nil
    SendNUIMessage({ action = 'open', game = game, opts = opts, label = label or '', text = texts() })
    SetNuiFocus(true, true)
    local limit = GetGameTimer() + ((tonumber(opts.seconds) or 45) + 5) * 1000
    while result == nil and GetGameTimer() < limit do
        Wait(50)
        if IsEntityDead(PlayerPedId()) then SendNUIMessage({ action = 'close' }) Wait(1000) break end
    end
    SetNuiFocus(false, false)
    open = false
    return result == true
end

RegisterNUICallback('done', function(data, cb)
    result = type(data) == 'table' and data.ok == true
    cb({})
end)

local function pickLevel(list, level, fallback)
    return (list or {})[level or ''] or (list or {})[fallback] or {}
end

function MGLockpick(level, label)
    local M = Config.Minigames
    if not M.Enabled then return lib.skillCheck({ 'easy', 'medium', 'medium' }, { 'w', 'a', 's', 'd' }) == true end
    return play('lock', pickLevel(M.Lockpick, level, 'medium'), label)
end

function MGSafeCrack(level, label)
    local M = Config.Minigames
    if not M.Enabled then return lib.skillCheck({ 'easy', 'medium' }, { 'w', 'a', 's', 'd' }) == true end
    return play('safe', pickLevel(M.Safe, level, 'medium'), label)
end

exports('Lockpick', function(level, label) return MGLockpick(level, label) end)
exports('SafeCrack', function(level, label) return MGSafeCrack(level, label) end)
exports('IsMinigameOpen', function() return open end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
