-- ============================================================
-- MULTIchat :: client
-- Opens the chat box (T), sends what the player types, and answers the
-- standard chat resource's events and exports (it provides 'chat').
-- GPL v3, part of MULTIcore.
-- ============================================================

local open = false
local hidden = false
local ready = false
local pending = {}   -- messages that arrived before the page was ready

local function nui(msg)
    if ready then SendNUIMessage(msg) else pending[#pending + 1] = msg end
end

-- only plain values go to the page
local function copy(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == 'string' or t == 'number' or t == 'boolean' then return v end
    if t ~= 'table' or depth > 4 then return nil end
    local out = {}
    for k, x in pairs(v) do
        if type(k) == 'string' or type(k) == 'number' then out[k] = copy(x, depth + 1) end
    end
    return out
end

-- ---------------------------------------------------------------
-- messages and suggestions (standard chat events)
-- ---------------------------------------------------------------

local API = {}

function API.addMessage(message)
    if type(message) == 'string' then message = { args = { message } } end
    if type(message) ~= 'table' then return end
    nui({ action = 'message', message = copy(message) })
end

function API.addSuggestion(name, help, params)
    if type(name) == 'table' then return API.addSuggestions({ name }) end
    nui({ action = 'suggestions', list = { { name = tostring(name), help = help, params = copy(params) } } })
end

function API.addSuggestions(list)
    if type(list) ~= 'table' then return end
    local out = {}
    for _, s in ipairs(list) do
        if type(s) == 'table' and s.name then out[#out + 1] = { name = tostring(s.name), help = s.help, params = copy(s.params) } end
    end
    nui({ action = 'suggestions', list = out })
end

function API.removeSuggestion(name)
    nui({ action = 'removeSuggestion', name = tostring(name) })
end

function API.addTemplate(id, html)
    nui({ action = 'template', id = tostring(id), html = tostring(html) })
end

function API.clear()
    nui({ action = 'clear' })
end

-- accepted so scripts written for the standard chat do not error
function API.addMode() end
function API.removeMode() end

RegisterNetEvent('chat:addMessage', API.addMessage)
RegisterNetEvent('chat:addSuggestion', API.addSuggestion)
RegisterNetEvent('chat:addSuggestions', API.addSuggestions)
RegisterNetEvent('chat:removeSuggestion', API.removeSuggestion)
RegisterNetEvent('chat:addTemplate', API.addTemplate)
RegisterNetEvent('chat:clear', API.clear)
RegisterNetEvent('chat:addMode', API.addMode)
RegisterNetEvent('chat:removeMode', API.removeMode)

-- the oldest chat event: (author, colour, text)
RegisterNetEvent('chatMessage', function(author, color, text)
    local args = { tostring(text or '') }
    if author and author ~= '' then table.insert(args, 1, tostring(author)) end
    API.addMessage({ color = color, multiline = true, args = args })
end)

-- a server print sent to this player
RegisterNetEvent('__cfx_internal:serverPrint', function(msg)
    print(msg)
end)

for name, fn in pairs(API) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_chat_%s'):format(name), function(setCB) setCB(fn) end)
end

-- ---------------------------------------------------------------
-- the page
-- ---------------------------------------------------------------

local function close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('loaded', function(_, cb)
    ready = true
    cb('ok')
    SendNUIMessage({
        action = 'init',
        text = _LT(),
        lang = _LCode and _LCode() or 'en',
        scale = Config.Scale,
        max = Config.MaxMessages,
        maxLength = Config.MaxLength,
        fade = Config.FadeSeconds,
        styles = Config.Styles,
    })
    for _, msg in ipairs(pending) do SendNUIMessage(msg) end
    pending = {}
    TriggerServerEvent('chat:init')
end)

RegisterNUICallback('chatResult', function(data, cb)
    cb('ok')
    close()
    local text = type(data) == 'table' and not data.canceled and tostring(data.message or '') or ''
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end
    if text:sub(1, 1) == '/' then
        ExecuteCommand(text:sub(2))
    else
        TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), { 255, 255, 255 }, text)
    end
end)

-- ---------------------------------------------------------------
-- own commands
-- ---------------------------------------------------------------

if Config.Commands.Clear then
    RegisterCommand(Config.Commands.Clear, function() API.clear() end, false)
end

if Config.Commands.Hide then
    RegisterCommand(Config.Commands.Hide, function()
        hidden = not hidden
        SendNUIMessage({ action = 'hidden', on = hidden })
        if not hidden then API.addMessage({ mc = 'system', args = { _L('chat_shown') } }) end
    end, false)
end

CreateThread(function()
    Wait(1000)
    local c = Config.Commands
    local function suggest(name, help, param)
        if name then API.addSuggestion('/' .. name, help, param and { { name = param, help = '' } } or nil) end
    end
    suggest(c.Me, _L('help_me'), _L('param_action'))
    suggest(c.Do, _L('help_do'), _L('param_text'))
    suggest(c.Try, _L('help_try'), _L('param_action'))
    suggest(c.Clear, _L('help_clear'))
    suggest(c.Hide, _L('help_hide'))
end)

-- ---------------------------------------------------------------
-- open with T
-- ---------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(0)
        if not open then
            if ready and not IsPauseMenuActive() and IsControlJustReleased(0, Config.OpenKey) then
                open = true
                SetNuiFocus(true, true)
                SendNUIMessage({ action = 'open' })
            end
        elseif IsPauseMenuActive() then
            close()
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
