-- ============================================================
-- MULTIadmin :: script performance (Performance page)
--
-- Server: FXServer's own profiler. MULTIadmin runs the console commands
--   profiler record <frames>   and   profiler saveJSON <file>
-- reads the file back and adds up, per resource, how long the server spent
-- inside it (every "tick" and every event the resource handled). That is the
-- same data as the profiler's Chrome view, real milliseconds. The commands
-- need three lines in server.cfg:
--   add_ace resource.MULTIadmin command.profiler allow
--   add_ace resource.MULTIadmin command.record allow
--   add_ace resource.MULTIadmin command.saveJSON allow
--
-- A player's PC: scripts cannot read the game's per-resource times on a
-- player's PC (resmon / the client profiler are console tools only). The
-- player's game measures its own frame time for a few seconds (GET_FRAME_TIME)
-- and reports frames per second, average / slowest frames and how many
-- resources run there. Per-resource ms on a PC: the player types  resmon 1
-- in the F8 console.
-- ============================================================

local H = Admin.Handlers
local P = Config.Perf
local busyServer = false
local busyPlayer = {}

local function round(n, d)
    local m = 10 ^ (d or 2)
    return math.floor((tonumber(n) or 0) * m + 0.5) / m
end

-- ------------------------------------------------------------
-- server: profiler file -> per-resource totals
-- ------------------------------------------------------------

--- Adds up a profiler JSON (Chrome trace) by resource. Time a resource spent calling
--- into another resource (an event it triggered, an export) counts for the other one.
--- Returns { frames, wallMs, rows = { { name, totalMs, avgMs, maxMs, share, calls, ticks, events } } }
function Admin.ParseProfile(text)
    local frames, firstTs, lastTs = 0, nil, nil
    local stacks = {}      -- tid -> stack of open entries
    local res = {}         -- name -> totals
    local perFrame = {}    -- name -> ms in the current frame
    local count = 0

    local function closeFrame()
        for name, ms in pairs(perFrame) do
            local r = res[name]
            if ms > r.maxUs then r.maxUs = ms end
        end
        perFrame = {}
    end

    -- frame markers and counters carry nested "args" objects: flatten them so each event is one {...}
    text = text:gsub('"args"%s*:%s*%b{}', '"args":0')
    for obj in text:gmatch('{[^{}]*}') do
        count = count + 1
        if count % 4000 == 0 then Wait(0) end   -- a big file never stalls the server
        local name = obj:match('"name"%s*:%s*"(.-)"')
        local ph = obj:match('"ph"%s*:%s*"(%a)"')
        local ts = tonumber(obj:match('"ts"%s*:%s*(%d+)'))
        if name == 'BeginFrame' and ts then
            closeFrame()
            frames = frames + 1
            firstTs = firstTs or ts
            lastTs = ts
        elseif (ph == 'B' or ph == 'E') and ts and obj:find('blink.user_timing', 1, true) then
            local tid = obj:match('"tid"%s*:%s*(%d+)') or '0'
            local st = stacks[tid]
            if not st then st = {} stacks[tid] = st end
            if ph == 'B' then
                local cause, resource = name:match('^(.*) %(([^%(%)]+)%)$')
                local isRes = resource ~= nil and GetResourceState(resource) ~= 'missing'
                st[#st + 1] = { ts = ts, res = isRes and resource or nil, event = isRes and cause ~= 'tick', inner = 0 }
            elseif #st > 0 then
                local e = table.remove(st)
                local dur = math.max(0, ts - e.ts)
                if e.res then
                    -- time spent in a resource called from inside this one is that resource's, not this one's
                    local self = math.max(0, dur - e.inner)
                    local r = res[e.res]
                    if not r then
                        r = { name = e.res, us = 0, maxUs = 0, calls = 0, ticks = 0, events = 0 }
                        res[e.res] = r
                    end
                    r.us = r.us + self
                    r.calls = r.calls + 1
                    if e.event then r.events = r.events + 1 else r.ticks = r.ticks + 1 end
                    perFrame[e.res] = (perFrame[e.res] or 0) + self
                    for i = #st, 1, -1 do
                        if st[i].res then st[i].inner = st[i].inner + dur break end
                    end
                end
            end
        end
        if ts and (not lastTs or ts > lastTs) and firstTs then lastTs = ts end
    end
    closeFrame()

    local wallUs = (firstTs and lastTs and lastTs > firstTs) and (lastTs - firstTs) or 0
    local rows = {}
    for _, r in pairs(res) do
        rows[#rows + 1] = {
            name = r.name,
            totalMs = round(r.us / 1000, 3),
            avgMs = frames > 0 and round(r.us / 1000 / frames, 3) or 0,
            maxMs = round(r.maxUs / 1000, 3),
            share = wallUs > 0 and round(r.us / wallUs * 100, 2) or 0,
            calls = r.calls, ticks = r.ticks, events = r.events,
        }
    end
    table.sort(rows, function(a, b) return a.totalMs > b.totalMs end)
    return { frames = frames, wallMs = round(wallUs / 1000, 1), rows = rows }
end

local function readFile(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('a')
    f:close()
    return s
end

--- Records the server for Config.Perf.ServerFrames ticks. Returns data | nil, error key
function Admin.ProfileServer(frames)
    if busyServer then return nil, 'perf_busy' end
    if ProfilerIsRecording() then return nil, 'perf_recording' end
    busyServer = true
    local ok, a, b = pcall(function()
        frames = math.max(10, math.min(1000, math.floor(tonumber(frames) or P.ServerFrames)))
        -- an absolute path inside this resource: the profiler and Lua do not agree on the working folder
        local file = (GetResourcePath(GetCurrentResourceName()):gsub('\\', '/'):gsub('/+', '/')) .. '/' .. P.ProfileFile
        os.remove(file)
        ExecuteCommand(('profiler record %d'):format(frames))
        -- the command runs on the next server tick; when the ace is missing it never starts
        local started = false
        for _ = 1, 20 do
            Wait(50)
            if ProfilerIsRecording() then started = true break end
        end
        if not started then return nil, 'perf_no_ace' end
        local deadline = GetGameTimer() + P.TimeoutSeconds * 1000
        while ProfilerIsRecording() do
            if GetGameTimer() > deadline then
                ExecuteCommand('profiler record stop')
                break
            end
            Wait(100)
        end
        ExecuteCommand(('profiler saveJSON "%s"'):format(file))
        -- the file is written off the main thread: wait until it is complete
        local text, lastSize
        deadline = GetGameTimer() + P.TimeoutSeconds * 1000
        while GetGameTimer() < deadline do
            Wait(250)
            local s = readFile(file)
            local done = s and s:find('"traceEvents"', 1, true) and s:match('}%s*$')
            if done and #s == lastSize then text = s break end   -- complete and no longer growing
            lastSize = s and #s or nil
        end
        os.remove(file)
        if not text then return nil, 'perf_no_file' end
        local data = Admin.ParseProfile(text)
        data.kind = 'server'
        data.warnMs, data.heavyMs = P.ServerWarnMs, P.ServerHeavyMs
        return data
    end)
    busyServer = false
    if not ok then
        print(('^1[MULTIadmin]^7 profiling failed: %s'):format(tostring(a)))
        return nil, 'err_failed'
    end
    return a, b
end

-- ------------------------------------------------------------
-- a player's PC: frame times measured by that player's game
-- ------------------------------------------------------------

local function cleanClient(d)
    if type(d) ~= 'table' then return nil end
    local function num(v, max) v = tonumber(v) if not v or v ~= v or v < 0 then return 0 end return math.min(v, max) end
    local list = {}
    if type(d.resources) == 'table' then
        for i, n in ipairs(d.resources) do
            if i > 400 then break end
            if type(n) == 'string' then list[#list + 1] = n:gsub('[^%w%-%_%.%[%]]', ''):sub(1, 64) end
        end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return {
        kind = 'client',
        frames = math.floor(num(d.frames, 100000)),
        seconds = num(d.seconds, 120),
        fps = round(num(d.fps, 1000), 1),
        avgMs = round(num(d.avgMs, 10000), 2),
        worstMs = round(num(d.worstMs, 10000), 2),   -- slowest 1 % of frames (average)
        maxMs = round(num(d.maxMs, 100000), 2),
        slowFrames = math.floor(num(d.slowFrames, 100000)),
        resources = list,
        warnMs = P.ClientWarnMs, heavyMs = P.ClientHeavyMs,
    }
end

function Admin.ProfilePlayer(target)
    if busyPlayer[target] then return nil, 'perf_busy' end
    busyPlayer[target] = true
    local p = promise.new()
    lib.callback('MULTIadmin:perfSample', target, function(d) p:resolve(d) end, P.ClientSeconds, P.ClientSlowFrameMs)
    local deadline = GetGameTimer() + (P.ClientSeconds + P.ClientExtraWaitSeconds) * 1000
    while p.state == 0 and GetGameTimer() < deadline do Wait(100) end
    busyPlayer[target] = nil
    if p.state == 0 then return nil, 'perf_no_answer' end
    local data = cleanClient(p.value)
    if not data then return nil, 'perf_no_answer' end
    return data
end

AddEventHandler('playerDropped', function() busyPlayer[source] = nil end)

-- ------------------------------------------------------------
-- menu action
-- ------------------------------------------------------------

H.perf = function(src, data)
    if data.target == 'server' then
        local res, err = Admin.ProfileServer(data.frames)
        if not res then return false, _L(err) end
        Admin.Log(src, 'perf', ('server profile, %d ticks, %d resources'):format(res.frames, #res.rows))
        return true, nil, res
    end
    local t = tonumber(data.target)
    t = t and math.floor(t)
    if not t or t < 1 or not GetPlayerName(t) then return false, _L('err_offline') end
    local res, err = Admin.ProfilePlayer(t)
    if not res then return false, _L(err) end
    res.player = t
    res.playerName = GetPlayerName(t)
    Admin.Log(src, 'perf', ('measured the PC of %s'):format(Admin.Who(t)))
    return true, nil, res
end

-- self-test only
if GetConvar('multicore_selftest', 'false') == 'true' then
    -- the profile waits for the server, so the answer comes back as an event, not as the export's return
    exports('_TestProfileServer', function(frames)
        CreateThread(function()
            local data, err = Admin.ProfileServer(frames)
            TriggerEvent('MULTIadmin:test:profiled', data, err)
        end)
        return true
    end)
    exports('_TestParseProfile', function(text) return Admin.ParseProfile(text) end)
end
