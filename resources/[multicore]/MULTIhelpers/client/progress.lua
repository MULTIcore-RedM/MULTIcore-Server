-- ============================================================
-- MULTIhelpers :: progress bar (stands in for vorp_progressbar)
--
--   local progressbar = exports.vorp_progressbar:initiate()
--   progressbar.start(message, ms, callback, theme, color, width, focus)
--     theme  'linear' (default) | 'circle' | 'innercircle'
--     color  any CSS colour ('#b8322a', 'rgb(...)'); width any CSS width ('20vw', '300px', 300)
--     focus  false = the bar does not take the keyboard (player can keep moving)
--   exports.vorp_progressbar:CancelNext(cb)   -- drops the oldest running bar, cb(barInfo)
--   exports.vorp_progressbar:CancelAll(cb)    -- drops every bar, cb({ barInfo, ... })
--   exports.progressBars:startUI(ms, text)    -- the old progressBars export (when not running)
--
-- The callback runs (no arguments) when the bar finishes; a cancelled bar never calls back.
-- Written from VORP's public docs (docs.vorp-core.com/api-reference/progressbar) and from
-- how scripts call it. No VORP code is used.
-- ============================================================

local Cfg = Config.Progress

local bars = {}     -- running bars, oldest first
local shown = nil   -- the bar on screen (the newest)
local seq = 0

local function wantsFocus()
    for _, b in ipairs(bars) do
        if b.focus then return true end
    end
    return false
end

local function syncFocus()
    Helpers.SetFocus('progress', wantsFocus() and { keyboard = true, cursor = false } or nil)
end

local function draw(b)
    shown = b
    Helpers.Send('progressShow', {
        id = b.id,
        label = type(b.message) == 'string' and b.message or tostring(b.message or ''),
        duration = b.ms,
        elapsed = GetGameTimer() - b.started,
        theme = b.theme,
        color = b.color,
        width = b.width,
    })
end

local function redraw()
    local newest = bars[#bars]
    if newest then
        if newest ~= shown then draw(newest) end
    elseif shown then
        shown = nil
        Helpers.Send('progressHide')
    end
    syncFocus()
end

local function removeBar(b)
    for i, x in ipairs(bars) do
        if x == b then table.remove(bars, i) return true end
    end
    return false
end

local function start(message, ms, cb, theme, color, width, focus)
    ms = math.max(0, math.floor(tonumber(ms) or 0))
    if theme ~= 'linear' and theme ~= 'circle' and theme ~= 'innercircle' then theme = Cfg.DefaultTheme or 'linear' end
    if type(width) == 'number' then width = width .. 'px' end
    seq = seq + 1
    local b = {
        id = seq, message = message, callback = cb, ms = ms, theme = theme,
        color = type(color) == 'string' and color or Cfg.Color,
        width = type(width) == 'string' and width or nil,   -- nil = Config.Progress.Width / CircleSize
        focus = focus ~= false and Cfg.TakeFocus,
        owner = GetInvokingResource(),
        started = GetGameTimer(),
    }
    bars[#bars + 1] = b
    draw(b)
    syncFocus()
    Helpers.Debug('progress', b.message, ms)
    SetTimeout(ms, function()
        if not removeBar(b) then return end   -- cancelled meanwhile: no callback
        redraw()
        if b.callback then Helpers.SafeCall(b.callback) end
    end)
end

local function info(b)
    return { message = b.message, duration = b.ms, theme = b.theme, focus = b.focus }
end

local function cancelNext()
    local b = bars[1]
    if not b then return nil end
    removeBar(b)
    redraw()
    return info(b)
end

-- A caller stopped: drop its bars without calling back into it.
AddEventHandler('onClientResourceStop', function(res)
    local changed = false
    for i = #bars, 1, -1 do
        if bars[i].owner == res then table.remove(bars, i) changed = true end
    end
    if changed then redraw() end
end)

-- ------------------------------------------------------------ exports
local api = { start = start }

Helpers.Export('initiate', function() return api end, { 'vorp_progressbar' })

Helpers.Export('CancelNext', function(cb)
    local c = cancelNext()
    if cb then Helpers.SafeCall(cb, c or {}) end
    return c
end, { 'vorp_progressbar' })

Helpers.Export('CancelAll', function(cb)
    local list = {}
    while bars[1] do list[#list + 1] = cancelNext() end
    if cb then Helpers.SafeCall(cb, list) end
    return list
end, { 'vorp_progressbar' })

if Cfg.ProgressBarsStartUI then
    Helpers.Export('startUI', function(ms, text)
        start(text, ms, nil, nil, nil, nil, false)
    end, { 'progressBars' })
end
