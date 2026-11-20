-- ============================================================
-- MULTIserver :: Discord logs
-- Answers rsg-log's event  rsg-log:server:CreateLog (name, title,
-- color, message, tagEveryone)  the way RSG v2's rsg-essentials
-- logs.lua does (event name, argument order and colour names come
-- from it, GPL v3, see CREDITS.md), with MULTIserver's own routing:
--   convar <prefix>_<name>  ->  convar <prefix>  ->  console.
-- Webhook URLs are read from server convars only and are never
-- printed. Posts go out one at a time from a queue; a 429 from
-- Discord waits the time Discord asks for and tries again.
-- ============================================================

local C = Config.Logs
Logs = {}

local queue = {}          -- { name, route, url, body, tries }
Logs.http = PerformHttpRequest   -- swapped for a recorder in self-test dry-run mode

-- ---------------------------------------------------------------
-- routing
-- ---------------------------------------------------------------

local function cleanName(name)
    name = tostring(name or 'default'):lower():gsub('[^%w_]', '')
    if name == '' then name = 'default' end
    return name
end
Logs.CleanName = cleanName

local function validUrl(u) return type(u) == 'string' and u:find('^https://') ~= nil end

local ignored = {}
for _, n in ipairs(C.Ignore or {}) do ignored[cleanName(n)] = true end

--- Which convar a log name goes to: '<prefix>_<name>', '<prefix>' or nil (console only).
--- Second value is the URL (internal use; never print it).
function Logs.Route(name)
    name = cleanName(name)
    if ignored[name] then return nil, nil, 'ignored' end
    local key = C.ConvarPrefix .. '_' .. name
    local url = GetConvar(key, '')
    if validUrl(url) then return key, url end
    if C.UseDefault then
        url = GetConvar(C.ConvarPrefix, '')
        if validUrl(url) then return C.ConvarPrefix, url end
    end
    return nil, nil, 'none'
end

-- ---------------------------------------------------------------
-- payload
-- ---------------------------------------------------------------

local function colour(c)
    if type(c) == 'number' then return math.floor(c) end
    if type(c) == 'string' then
        local hex = c:match('^#?(%x%x%x%x%x%x)$')
        if hex then return tonumber(hex, 16) end
        if C.Colors[c:lower()] then return C.Colors[c:lower()] end
    end
    return C.Colors.default
end
Logs.Colour = colour

local function cut(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n - 3) .. '...' end
    return s
end

local function payload(title, color, message, tag)
    local avatar = GetConvar(C.AvatarConvar, '')
    local mention = tag and C.AllowTagEveryone
    return json.encode({
        username = C.BotName,
        avatar_url = validUrl(avatar) and avatar or nil,
        content = mention and '@everyone' or nil,
        allowed_mentions = { parse = mention and { 'everyone' } or {} },
        embeds = { {
            title = cut(title, C.MaxTitleLength),
            description = cut(message, C.MaxMessageLength),
            color = colour(color),
            footer = { text = os.date('%c') },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
end

local function console(name, title, message)
    local plain = tostring(message or ''):gsub('%*%*', '')
    print(('^3[MULTIserver log:%s]^7 %s - %s'):format(name, tostring(title or ''), plain))
end

-- ---------------------------------------------------------------
-- adding a log
-- ---------------------------------------------------------------

--- Queues one log. Returns the route used ('<convar name>' | 'console' | 'ignored' | 'off').
function Logs.Add(name, title, color, message, tagEveryone)
    if not C.Enabled then return 'off' end
    name = cleanName(name)
    local route, url, why = Logs.Route(name)
    if not route then
        if why == 'ignored' then return 'ignored' end
        if C.ConsoleFallback then console(name, title, message) end
        return 'console'
    end
    if C.ConsoleAlways then console(name, title, message) end
    if #queue >= C.MaxQueue then
        local dropped = table.remove(queue, 1)
        print(('^3[MULTIserver]^7 %s'):format(_L('log_queue_full', dropped.name)))
    end
    queue[#queue + 1] = { name = name, route = route, url = url, body = payload(title, color, message, tagEveryone == true), tries = 0 }
    return route
end

-- ---------------------------------------------------------------
-- sending (one at a time, in order)
-- ---------------------------------------------------------------

local function retryAfterMs(body, headers)
    local ok, data = pcall(json.decode, body or '')
    if ok and type(data) == 'table' and tonumber(data.retry_after) then
        local s = tonumber(data.retry_after)
        return math.ceil((s > 1000 and s or s * 1000))   -- old API gave ms, new API gives seconds
    end
    if type(headers) == 'table' then
        local h = headers['Retry-After'] or headers['retry-after']
        if tonumber(h) then return math.ceil(tonumber(h) * 1000) end
    end
    return C.RetryFallbackMs
end

local function sendOne(entry)
    local p = promise.new()
    Logs.http(entry.url, function(status, body, headers)
        p:resolve({ status = tonumber(status) or 0, body = body, headers = headers })
    end, 'POST', entry.body, { ['Content-Type'] = 'application/json' })
    local res = Citizen.Await(p)
    return res.status, res.body, res.headers
end

CreateThread(function()
    while true do
        local entry = queue[1]
        if not entry then
            Wait(250)
        else
            local status, body, headers = sendOne(entry)
            local waitMs = C.SendGapMs
            if status >= 200 and status < 300 then
                table.remove(queue, 1)
            elseif status == 429 or status == 0 or status >= 500 then
                entry.tries = entry.tries + 1
                if entry.tries > C.MaxRetries then
                    table.remove(queue, 1)
                    print(('^3[MULTIserver]^7 %s'):format(_L('log_gave_up', entry.name, status)))
                else
                    waitMs = status == 429 and retryAfterMs(body, headers) or C.ErrorRetryMs
                end
            else
                table.remove(queue, 1)
                print(('^3[MULTIserver]^7 %s'):format(_L('log_refused', entry.name, status, entry.route)))
            end
            Wait(math.max(0, waitMs))
        end
    end
end)

-- ---------------------------------------------------------------
-- logs sent by game clients: allowed names only, rate limited, no @everyone
-- ---------------------------------------------------------------

local clientCount = {}   -- src -> { minute, n }

function Logs.FromClient(src, name, title, color, message)
    local cc = C.Client
    name = cleanName(name)
    if not cc.Enabled or not cc.Names[name] then return 'refused' end
    local minute = math.floor(os.time() / 60)
    local c = clientCount[src]
    if not c or c.minute ~= minute then c = { minute = minute, n = 0 } clientCount[src] = c end
    c.n = c.n + 1
    if c.n > cc.PerMinute then return 'limited' end
    local from = _L('log_from_client', GetPlayerName(src) or '?', src)
    return Logs.Add(name, title, color, cut(message, cc.MaxLength) .. '\n' .. from, false)
end

AddEventHandler('playerDropped', function() clientCount[source] = nil end)

-- rsg-log's event (server scripts with TriggerEvent, RSG client scripts with TriggerServerEvent)
RegisterNetEvent('rsg-log:server:CreateLog', function(name, title, color, message, tagEveryone)
    local src = tonumber(source) or 0
    if src > 0 and GetInvokingResource() == nil then
        Logs.FromClient(src, name, title, color, message)
        return
    end
    Logs.Add(name, title, color, message, tagEveryone)
end)

-- ---------------------------------------------------------------
-- MULTI events worth a log (only ones the MULTI scripts really fire)
-- ---------------------------------------------------------------

local function who(src)
    local P = RSGCore.Functions.GetPlayer(src)
    local char = P and P.PlayerData.charinfo and (('%s %s'):format(P.PlayerData.charinfo.firstname or '', P.PlayerData.charinfo.lastname or '')) or '?'
    return _L('log_who', GetPlayerName(src) or '?', tonumber(src) or 0, char)
end

AddEventHandler('MULTIcore:characterSelected', function(src, citizenid, isNew)
    if not isNew or not C.Events.CharacterCreated then return end
    Logs.Add(C.Events.CharacterCreated, _L('log_char_created_title'), 'green', _L('log_char_created', who(src), tostring(citizenid)))
end)

AddEventHandler('MULTIlaw:server:jailed', function(src, minutes, place, officer)
    if not C.Events.Jailed then return end
    local by = tonumber(officer) and who(officer) or _L('log_nobody')
    Logs.Add(C.Events.Jailed, _L('log_jailed_title'), 'orange', _L('log_jailed', who(src), tonumber(minutes) or 0, tostring(place or '?'), by))
end)

AddEventHandler('MULTIlaw:server:released', function(src, citizenid)
    if not C.Events.Released then return end
    Logs.Add(C.Events.Released, _L('log_released_title'), 'blue', _L('log_released', tonumber(src) and who(src) or '?', tostring(citizenid or '?')))
end)

-- ---------------------------------------------------------------
-- exports and the test command
-- ---------------------------------------------------------------

exports('Log', function(name, title, color, message, tagEveryone) return Logs.Add(name, title, color, message, tagEveryone) end)
--- The convar a log name is routed to ('multiserver_webhook_<name>' / 'multiserver_webhook'), or nil. Never the URL.
exports('GetLogRoute', function(name) return (Logs.Route(name)) end)
exports('GetLogQueueLength', function() return #queue end)

RegisterCommand('multiserver_testlog', function(src, args)
    if not MS.IsAdmin(src) then return end
    local name = args[1] or 'default'
    local route = Logs.Add(name, _L('log_test_title'), 'default', _L('log_test_message', cleanName(name)))
    MS.Reply(src, _L('log_test_sent', cleanName(name), route), 'success')
end, false)

-- self-test only: swap HTTP for a recorder that answers from a list of statuses
if MS.testMode then
    local sent, script = {}, {}
    exports('_TestLogs', function(cmd, arg)
        if cmd == 'dryrun' then
            sent, script = {}, arg or {}
            Logs.http = function(url, cb, method, body, headers)
                local st = table.remove(script, 1) or { 204 }
                sent[#sent + 1] = { route = (function()
                    for _, e in ipairs(queue) do if e.url == url then return e.route end end
                end)(), body = json.decode(body), status = st[1] }
                cb(st[1], st[2] or '', st[3] or {})
            end
            return true
        elseif cmd == 'sent' then return sent
        elseif cmd == 'pending' then return #queue
        elseif cmd == 'config' then C[arg[1]] = arg[2] return true
        elseif cmd == 'client' then return Logs.FromClient(arg[1], arg[2], arg[3], arg[4], arg[5])
        end
    end)
end
