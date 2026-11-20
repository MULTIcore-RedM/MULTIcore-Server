-- ============================================================
-- MULTIchat :: server
-- Plain text, /me, /do, /try, command suggestions, and the standard chat
-- resource's server events and exports (it provides 'chat').
-- GPL v3, part of MULTIcore.
-- ============================================================

local lastSent = {}   -- [src] = GetGameTimer() of the last message

-- ---------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

--- One line, no colour codes, no longer than Config.MaxLength.
local function clean(s)
    s = tostring(s or ''):gsub('[\r\n\t]', ' '):gsub('%^%d', '')
    s = trim(s)
    if #s > Config.MaxLength then s = s:sub(1, Config.MaxLength) end
    return s
end

local function charName(src)
    if Config.UseCharacterName then
        local ok, player = pcall(function() return exports['rsg-core']:GetCoreObject().Functions.GetPlayer(src) end)
        local info = ok and player and player.PlayerData and player.PlayerData.charinfo
        if info then
            local n = trim(('%s %s'):format(info.firstname or '', info.lastname or ''))
            if n ~= '' then return n end
        end
    end
    return GetPlayerName(src) or ('ID ' .. tostring(src))
end

local function tooFast(src)
    local now = GetGameTimer()
    if lastSent[src] and now - lastSent[src] < Config.CooldownMs then
        TriggerClientEvent('chat:addMessage', src, { mc = 'system', args = { _L('too_fast') } })
        return true
    end
    lastSent[src] = now
    return false
end

--- Sends a message to every player within range metres of src (same routing bucket).
--- range = nil sends it to everyone.
local function sendNear(src, range, message)
    local ped = GetPlayerPed(src)
    local here = ped ~= 0 and GetEntityCoords(ped)
    local bucket = GetPlayerRoutingBucket(src)
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local send = target == src
        if not send and GetPlayerRoutingBucket(target) == bucket then
            if not range then
                send = true
            elseif here then
                local other = GetPlayerPed(target)
                send = other ~= 0 and #(here - GetEntityCoords(other)) <= range
            end
        end
        if send then TriggerClientEvent('chat:addMessage', target, message) end
    end
end

local function log(kind, src, text)
    if Config.LogToConsole then print(('[MULTIchat] %s %s (%d): %s'):format(kind, charName(src), src, text)) end
end

-- ---------------------------------------------------------------
-- /me /do /try
-- ---------------------------------------------------------------

local function textOf(args, raw)
    -- the raw line keeps the player's own spacing; drop the command word
    local s = raw and raw:match('^%S+%s+(.+)$') or table.concat(args or {}, ' ')
    return clean(s)
end

local function roleplay(kind, build)
    return function(src, args, raw)
        if src <= 0 then return end
        local text = textOf(args, raw)
        if text == '' then
            TriggerClientEvent('chat:addMessage', src, { mc = 'system', args = { _L('need_text') } })
            return
        end
        if tooFast(src) then return end
        local message = build(src, text)
        sendNear(src, Config.Range[kind], message)
        log(kind, src, text)
    end
end

if Config.Commands.Me then
    RegisterCommand(Config.Commands.Me, roleplay('me', function(src, text)
        return { mc = 'me', args = { _L('me_line', charName(src), text) } }
    end), false)
end

if Config.Commands.Do then
    RegisterCommand(Config.Commands.Do, roleplay('do', function(src, text)
        -- capital first letter, the way a narrator writes it
        text = text:sub(1, 1):upper() .. text:sub(2)
        return { mc = 'do', args = { _L('do_line', text, charName(src)) } }
    end), false)
end

if Config.Commands.Try then
    RegisterCommand(Config.Commands.Try, roleplay('try', function(src, text)
        text = text:gsub('^[Tt][Oo]%s+', '')
        local ok = math.random(100) <= Config.TryChance
        -- the result is its own part so the page can colour it
        return { mc = 'try', ok = ok, args = { _L('try_line', charName(src), text), _L(ok and 'try_ok' or 'try_fail') } }
    end), false)
end

-- ---------------------------------------------------------------
-- plain text
-- ---------------------------------------------------------------

RegisterNetEvent('_chat:messageEntered', function(_, _, message)
    local src = source
    message = clean(message)
    if message == '' or message:sub(1, 1) == '/' then return end

    -- other scripts may cancel it (the standard chat event)
    TriggerEvent('chatMessage', src, charName(src), message)
    if WasEventCanceled() then return end

    if Config.PlainText == 'off' then
        TriggerClientEvent('chat:addMessage', src, { mc = 'system', args = { _L('plain_off') } })
        return
    end
    if tooFast(src) then return end
    sendNear(src, Config.PlainText ~= 'global' and Config.Range.say or nil, { mc = 'say', args = { charName(src), message } })
    log('say', src, message)
end)

-- a command no script registered
AddEventHandler('__cfx_internal:commandFallback', function(command)
    local src = source
    TriggerEvent('chatMessage', src, charName(src), '/' .. command)
    CancelEvent()
    local name = tostring(command):match('^(%S+)') or ''
    TriggerClientEvent('chat:addMessage', src, { mc = 'system', args = { _L('unknown_command', clean(name)) } })
end)

AddEventHandler('playerDropped', function() lastSent[source] = nil end)

-- ---------------------------------------------------------------
-- suggestions: every command the player may use is listed as they type
-- ---------------------------------------------------------------

local function refresh(src)
    local list = {}
    for _, c in ipairs(GetRegisteredCommands()) do
        if IsPlayerAceAllowed(tostring(src), ('command.%s'):format(c.name)) then
            list[#list + 1] = { name = '/' .. c.name, help = '' }
        end
    end
    TriggerClientEvent('chat:addSuggestions', src, list)
end

RegisterNetEvent('chat:init', function() refresh(source) end)

AddEventHandler('onServerResourceStart', function()
    -- give the resource a moment to register its commands
    SetTimeout(500, function()
        for _, id in ipairs(GetPlayers()) do refresh(tonumber(id)) end
    end)
end)

AddEventHandler('onServerResourceStop', function(res)
    for _, c in ipairs(GetRegisteredCommands()) do
        if c.resource == res then TriggerClientEvent('chat:removeSuggestion', -1, '/' .. c.name) end
    end
end)

-- ---------------------------------------------------------------
-- exports (also answered as exports.chat)
-- ---------------------------------------------------------------

local API = {}

--- exports.MULTIchat:addMessage(target, message): target = player id or -1.
function API.addMessage(target, message)
    TriggerClientEvent('chat:addMessage', target or -1, message)
end

--- exports.MULTIchat:SendMe(src, text) / SendDo(src, text): a /me or /do line as if the player typed it.
function API.SendMe(src, text)
    text = clean(text)
    if text == '' then return end
    sendNear(src, Config.Range.me, { mc = 'me', args = { _L('me_line', charName(src), text) } })
end

function API.SendDo(src, text)
    text = clean(text)
    if text == '' then return end
    sendNear(src, Config.Range['do'], { mc = 'do', args = { _L('do_line', text:sub(1, 1):upper() .. text:sub(2), charName(src)) } })
end

--- Standard chat calls MULTIchat accepts but does not need (kept so scripts do not error).
function API.registerMessageHook() end
function API.registerMode() end
function API.unregisterMode() end

for name, fn in pairs(API) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_chat_%s'):format(name), function(setCB) setCB(fn) end)
end
