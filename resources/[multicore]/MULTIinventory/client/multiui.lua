--[[ RINGOui shim (same file in every RINGO script: client/multiui.lua)
     While the RINGOui resource is running, this script's ox_lib context menus,
     input boxes, confirms, progress bars, text prompts and notices are drawn by
     RINGOui in the RINGO Frontier look. Without RINGOui, ox_lib draws them
     exactly as before. Nothing here grants anything: every choice still goes
     through this script's own code and its server checks. ]]

if type(lib) ~= 'table' then return end

local ME = GetCurrentResourceName()
local UI = 'RINGOui'
local function up() return GetResourceState(UI) == 'started' end
local function ui() return exports[UI] end

local ox = {}
for _, k in ipairs({
    'registerContext', 'showContext', 'hideContext', 'getOpenContextMenu',
    'inputDialog', 'closeInputDialog', 'alertDialog', 'closeAlertDialog',
    'progressBar', 'progressCircle', 'progressActive', 'cancelProgress',
    'showTextUI', 'hideTextUI', 'isTextUIOpen', 'notify',
}) do
    local ok, fn = pcall(function() return lib[k] end)
    if ok and type(fn) == 'function' then ox[k] = fn end
end

local contexts, shown, openCtx = {}, {}, nil
local pending, seq = {}, 0
local textShown, lastText, oxText = false, nil, false
local progressToken = nil

-- copy only plain data RINGOui can draw (no functions, bounded depth). Tables
-- are either clean arrays (1..n) or string-keyed, so json.encode never sees a
-- mixed or sparse table.
local function plain(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == 'string' or t == 'number' or t == 'boolean' then return v end
    if t ~= 'table' or depth > 4 then return nil end
    local n, count = #v, 0
    for _ in pairs(v) do count = count + 1 end
    local out = {}
    if n > 0 and n == count then
        for i = 1, n do
            local c = plain(v[i], depth + 1)
            if c == nil then c = false end
            out[i] = c
        end
        return out
    end
    for k, x in pairs(v) do
        local c = plain(x, depth + 1)
        if c ~= nil and (type(k) == 'string' or type(k) == 'number') then out[tostring(k)] = c end
    end
    return out
end

local function await(token)
    local p = promise.new()
    pending[token] = p
    return p
end

local function nextToken() seq = seq + 1; return seq end

-- ------------------------------------------------------------- contexts ----
local function optionList(ctx)
    local opts = ctx.options or {}
    if opts[1] ~= nil or next(opts) == nil then return opts end
    local keys = {}
    for k in pairs(opts) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local list = {}
    for i, k in ipairs(keys) do
        local o = opts[k]
        if type(o) == 'table' then
            if o.title == nil then o.title = tostring(k) end
            list[i] = o
        end
    end
    return list
end

lib.registerContext = function(context)
    if type(context) ~= 'table' then return end
    if context.id then
        contexts[context.id] = context
    else
        for _, c in ipairs(context) do if type(c) == 'table' and c.id then contexts[c.id] = c end end
    end
    if ox.registerContext then pcall(ox.registerContext, context) end
end

lib.showContext = function(id)
    local ctx = contexts[id]
    if not up() or not ctx then
        if ox.showContext then return ox.showContext(id) end
        return
    end
    local list = optionList(ctx)
    local opts = {}
    for i, o in ipairs(list) do
        opts[i] = {
            title = o.title, description = o.description,
            icon = type(o.icon) == 'string' and o.icon or nil, iconColor = o.iconColor, iconAnimation = o.iconAnimation,
            image = o.image, progress = tonumber(o.progress), colorScheme = o.colorScheme,
            metadata = plain(o.metadata), disabled = o.disabled == true, readOnly = o.readOnly == true,
            arrow = o.arrow == true or o.menu ~= nil, menu = o.menu ~= nil,
            click = (o.onSelect ~= nil or o.event ~= nil or o.serverEvent ~= nil),
        }
    end
    shown[id] = list
    openCtx = id
    ui():openContext(ME, { id = id, title = ctx.title, back = ctx.menu ~= nil, canClose = ctx.canClose ~= false, options = opts })
end

lib.hideContext = function(onExit)
    local id = openCtx
    if id and up() and ui():closeContext(ME) then
        openCtx = nil
        if onExit and contexts[id] and contexts[id].onExit then contexts[id].onExit() end
        return
    end
    if ox.hideContext then return ox.hideContext(onExit) end
end

lib.getOpenContextMenu = function()
    if openCtx then return openCtx end
    if ox.getOpenContextMenu then return ox.getOpenContextMenu() end
end

local function onContext(r)
    local ctx = contexts[r.id]
    if openCtx == r.id then openCtx = nil end
    if not ctx then return end
    if r.act == 'select' then
        local o = (shown[r.id] or {})[r.key]
        if not o or o.disabled or o.readOnly then return end
        if o.menu then return lib.showContext(o.menu) end
        if o.onSelect then o.onSelect(o.args) end
        if o.event then TriggerEvent(o.event, o.args) end
        if o.serverEvent then TriggerServerEvent(o.serverEvent, o.args) end
    elseif r.act == 'back' then
        if ctx.onBack then ctx.onBack() end
        if ctx.menu then lib.showContext(ctx.menu) end
    elseif r.act == 'close' then
        if ctx.onExit then ctx.onExit() end
    end
end

-- --------------------------------------------------------- input / alert ----
local INPUT_TYPES = { input = true, number = true, checkbox = true, select = true, ['multi-select'] = true, slider = true, textarea = true }

lib.inputDialog = function(heading, rows, options)
    local list = {}
    local simple = up() and type(rows) == 'table'
    if simple then
        for i, row in ipairs(rows) do
            if type(row) == 'string' then row = { type = 'input', label = row } end
            if type(row) ~= 'table' or not INPUT_TYPES[row.type or 'input'] then simple = false break end
            list[i] = plain(row)
        end
    end
    if not simple then
        if ox.inputDialog then return ox.inputDialog(heading, rows, options) end
        return
    end
    local token = nextToken()
    local p = await(token)
    if not ui():openInput(ME, token, heading, list, plain(options)) then pending[token] = nil; return nil end
    return Citizen.Await(p)
end

lib.closeInputDialog = function()
    if up() and ui():closeDialog(ME, 'input') then return end
    if ox.closeInputDialog then return ox.closeInputDialog() end
end

lib.alertDialog = function(data, timeout)
    if not up() or type(data) ~= 'table' then
        if ox.alertDialog then return ox.alertDialog(data, timeout) end
        return
    end
    local token = nextToken()
    local p = await(token)
    if not ui():openAlert(ME, token, plain(data)) then pending[token] = nil; return nil end
    if tonumber(timeout) then
        SetTimeout(tonumber(timeout), function()
            if pending[token] then ui():closeDialog(ME, 'alert') end
        end)
    end
    return Citizen.Await(p)
end

lib.closeAlertDialog = function(reason)
    if up() and ui():closeDialog(ME, 'alert') then return end
    if ox.closeAlertDialog then return ox.closeAlertDialog(reason) end
end

-- -------------------------------------------------------------- progress ----
local function progress(data, circle)
    -- animations and props stay with ox_lib, which already handles them on RedM
    if not up() or type(data) ~= 'table' or data.anim or data.prop then
        local fn = circle and ox.progressCircle or ox.progressBar
        if fn then return fn(data) end
        return
    end
    local copy = plain(data)
    copy.circle = circle
    while true do
        if not up() then
            local fn = circle and ox.progressCircle or ox.progressBar
            return fn and fn(data)
        end
        local token = nextToken()
        local p = await(token)
        if ui():startProgress(ME, token, copy) then
            progressToken = token
            local ok = Citizen.Await(p)
            if progressToken == token then progressToken = nil end
            return ok
        end
        pending[token] = nil
        Wait(0) -- another progress bar is running; wait our turn like ox_lib does
    end
end

lib.progressBar = function(data) return progress(data, false) end
lib.progressCircle = function(data) return progress(data, true) end

lib.progressActive = function()
    if progressToken then return true end
    if ox.progressActive then return ox.progressActive() end
    return false
end

lib.cancelProgress = function()
    if progressToken and up() and ui():cancelProgress(ME) then return end
    if ox.cancelProgress then return ox.cancelProgress() end
end

-- ----------------------------------------------------------- text prompt ----
lib.showTextUI = function(text, options)
    if not up() then
        oxText = true
        if ox.showTextUI then return ox.showTextUI(text, options) end
        return
    end
    if textShown and lastText == text then return end
    if oxText and ox.hideTextUI then ox.hideTextUI(); oxText = false end
    if ui():showText(ME, tostring(text), plain(options)) then
        textShown, lastText = true, text
    end
end

lib.hideTextUI = function()
    if textShown then
        textShown, lastText = false, nil
        if up() then ui():hideText(ME) end
    end
    if oxText then
        oxText = false
        if ox.hideTextUI then ox.hideTextUI() end
    end
end

lib.isTextUIOpen = function()
    if textShown then return true, lastText end
    if ox.isTextUIOpen then return ox.isTextUIOpen() end
    return false
end

-- --------------------------------------------------------------- notices ----
lib.notify = function(data)
    if not up() or type(data) ~= 'table' then
        if ox.notify then return ox.notify(data) end
        return
    end
    ui():notify(plain(data))
end

-- ------------------------------------------------------------- replies ----
AddEventHandler('RINGOui:reply', function(r)
    if type(r) ~= 'table' or r.owner ~= ME then return end
    if r.kind == 'ctx' then
        CreateThread(function() onContext(r) end)
        return
    end
    local p = pending[r.token]
    if not p then return end
    pending[r.token] = nil
    if r.kind == 'input' then p:resolve(r.values)
    elseif r.kind == 'alert' then p:resolve(r.result)
    elseif r.kind == 'progress' then p:resolve(r.ok)
    else p:resolve(nil) end
end)

-- RINGOui stopped: release anything still waiting on it.
AddEventHandler('onClientResourceStop', function(res)
    if res ~= UI then return end
    for token, p in pairs(pending) do pending[token] = nil; p:resolve(nil) end
    openCtx, textShown, lastText, progressToken = nil, false, nil, nil
end)
