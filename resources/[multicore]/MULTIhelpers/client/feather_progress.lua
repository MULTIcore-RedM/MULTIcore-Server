-- ============================================================
-- MULTIhelpers :: feather-progressbar stand-in
--
--   local progressbar = exports['feather-progressbar']:initiate()
--   progressbar.start(message, ms, callback, theme, color, width, focus)
--     theme 'linear' (default) | 'circle' | 'innercircle'; calls are queued
--   progressbar.onCancel(function() end)          -- one handler, runs when a bar is cancelled
--   exports['feather-progressbar']:cancelCurrentProgressBar()
--   exports['feather-progressbar']:startUI(ms, text)   -- the old progressBars export
--
-- Shown with MULTIhelpers' own progress bar. Own code, written from the
-- public API description. GPL v3, part of MULTIcore.
-- ============================================================

local RES = 'feather-progressbar'

local queue = {}        -- waiting bars, oldest first
local running = nil     -- { bar, callback, owner }
local cancelHandler = nil

local runNext

local function begin(job)
    running = job
    job.bar = Helpers.ProgressStart(job.message, job.ms, function()
        if running ~= job then return end
        running = nil
        if Helpers.Callable(job.callback) then Helpers.SafeCall(job.callback) end
        runNext()
    end, job.theme, job.color, job.width, job.focus)
end

runNext = function()
    if running then return end
    local job = table.remove(queue, 1)
    if job then begin(job) end
end

local function start(message, ms, callback, theme, color, width, focus)
    queue[#queue + 1] = {
        message = message, ms = ms, callback = callback, theme = theme, color = color,
        width = width or '20vw', focus = focus, owner = GetInvokingResource(),
    }
    runNext()
end

local function onCancel(fn)
    if Helpers.Callable(fn) then cancelHandler = fn end
end

local function cancelCurrent()
    local job = running
    if not job then return end
    running = nil
    Helpers.ProgressCancel(job.bar)
    if cancelHandler then Helpers.SafeCall(cancelHandler) end
    runNext()
end

-- the calling script stopped: drop its bars without calling back into it
AddEventHandler('onClientResourceStop', function(res)
    for i = #queue, 1, -1 do
        if queue[i].owner == res then table.remove(queue, i) end
    end
    if running and running.owner == res then
        local job = running
        running = nil
        Helpers.ProgressCancel(job.bar)
        runNext()
    end
end)

local api = { start = start, onCancel = onCancel }

-- initiate is also vorp_progressbar's export name, so it answers only as feather-progressbar
Helpers.ExportAs('initiate', function() return api end, { RES })
Helpers.ExportAs('cancelCurrentProgressBar', cancelCurrent, { RES })
Helpers.ExportAs('startUI', function(ms, text) start(text, ms, nil, nil, nil, nil, false) end, { RES })
