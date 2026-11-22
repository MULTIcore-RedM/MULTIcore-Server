-- ============================================================
-- MULTIcore :: notifications (client)
-- MULTIcore's own notification system, drawn by html/notify (the core's
-- ui_page). Settings in config_notify.lua, words in locales/notify_*.lua.
-- Written fresh for MULTIcore (GPL v3).
--
--   exports.MULTIcore:Notify({ text, title, type, style, duration, icon,
--                              iconDict, color, sound, id })   -> id
--   exports.MULTIcore:Notify(text, type, duration)               -> id
--   exports.MULTIcore:ClearNotify(id)
--   exports.MULTIcore:ClearAll()
--   event 'MULTIcore:notify'        (same arguments, from the server)
--   event 'MULTIcore:notify:clear'  (id or nil for all)
--
-- Also takes over RSGCore.Functions.Notify (this file loads after
-- client/functions.lua) and the older RSG client event 'RSGCore:Notify'.
-- ox_lib's own lib.notify / 'ox_lib:notify' stay ox_lib's.
-- ============================================================

MULTI = MULTI or {}

local Cfg = NotifyConfig

-- PLAY_SOUND_FRONTEND (audioName, audioRef, p2, p3): femga natives.json 0x67C540AA08E4A6F5
local PLAY_SOUND_FRONTEND = 0x67C540AA08E4A6F5

local STYLES = { toast = true, tip = true, objective = true, banner = true }

local nextId = 0
local shown = {}        -- dedupe key -> { id = id, untilAt = game time (math.huge when it stays) }
local byId = {}         -- id -> dedupe key
local lastSound = -math.huge

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local function str(v)
    if v == nil then return nil end
    v = tostring(v)
    if Cfg.StripGameCodes then v = v:gsub('~[%w_]*~', '') end
    if v == '' then return nil end
    return v
end

local function resolveType(t)
    t = type(t) == 'string' and t:lower() or nil
    if t and Cfg.Types[t] then return t end
    if t and Cfg.TypeAliases[t] and Cfg.Types[Cfg.TypeAliases[t]] then return Cfg.TypeAliases[t] end
    return Cfg.DefaultType
end

local function resolveStyle(s)
    s = type(s) == 'string' and s:lower() or nil
    if s and STYLES[s] then return s end
    return Cfg.DefaultStyle
end

local function resolveDuration(d, style)
    d = tonumber(d)
    if d and d < 0 then return -1 end                            -- stays until cleared
    if not d or d == 0 then d = Cfg.Styles[style].duration or 5000 end
    return math.floor(math.max(Cfg.MinDuration, math.min(Cfg.MaxDuration, d)))
end

local function resolveColor(c, fallback)
    if type(c) ~= 'string' or c == '' then return fallback end
    if c:match('^#%x%x%x%x?%x?%x?%x?%x?$') or c:match('^rgba?%(') then return c end
    return Cfg.Colors[c:upper()] or fallback
end

-- A short sign (up to 3 letters) is shown as the icon; long names such as
-- FontAwesome classes from RSG / ox_lib calls are ignored.
local function resolveGlyph(icon, fallback)
    if type(icon) ~= 'string' or icon == '' then return fallback end
    local len = utf8.len(icon)
    if len and len <= 3 then return icon end
    return fallback
end

-- sound: false = none; { ref = set, name = name } (VORP face) or { name, set } (config form)
local function soundPair(s)
    if type(s) ~= 'table' then return nil end
    local name = s.name or s[1]
    local set = s.ref or s.set or s[2]
    if type(name) == 'string' and name ~= '' and type(set) == 'string' and set ~= '' then return name, set end
    return nil
end

local function playSound(name, set)
    if not Cfg.Sounds or not name then return end
    local now = GetGameTimer()
    if now - lastSound < Cfg.SoundGap then return end
    lastSound = now
    Citizen.InvokeNative(PLAY_SOUND_FRONTEND, name, set, true, 0)
end

-- ------------------------------------------------------------
-- layout (where each style sits, its size) and look (how it is drawn)
-- ------------------------------------------------------------
local POSITIONS = {
    ['top-left'] = true, ['top-center'] = true, ['top-right'] = true,
    ['middle-left'] = true, ['center'] = true, ['middle-right'] = true,
    ['bottom-left'] = true, ['bottom-center'] = true, ['bottom-right'] = true,
}
local DEFAULT_POS = { toast = 'top-left', tip = 'bottom-center', objective = 'top-center', banner = 'center' }
local ALIGNS = { auto = true, left = true, center = true, right = true }
local KVP = 'multicore_notify_layout'

-- the player's own layout from /notifylayout (kept on their PC), per style
local mine = {}
do
    local ok, t = pcall(json.decode, GetResourceKvpString(KVP) or '')
    if ok and type(t) == 'table' then mine = t end
end

local function num(v, lo, hi, fallback)
    v = tonumber(v)
    if not v then return fallback end
    return math.max(lo, math.min(hi, v))
end

--- one style's place and size: the server's config, then the player's own layout on top
local function placeOf(style, serverOnly)
    local c = Cfg.Styles[style] or {}
    local pos = POSITIONS[c.position] and c.position or DEFAULT_POS[style]
    local p = {
        position = pos,
        x = tonumber(c.offsetX) or 0,
        y = tonumber(c.offsetY) or 0,
        width = num(c.width, 0, 4000, 0),
        scale = num(c.scale, 0.3, 3.0, 1.0),
        align = ALIGNS[c.align] and c.align or 'auto',
        max = math.floor(num(c.max, 1, 20, 1)),
    }
    -- older config: the banner had only top = % from the top of the screen
    if style == 'banner' and c.top and not c.position then
        p.position, p.y, p.topPct = 'top-center', 0, tonumber(c.top)
    end
    local o = not serverOnly and mine[style]
    if type(o) == 'table' then
        if POSITIONS[o.position] then p.position = o.position; p.topPct = nil end
        p.x = num(o.x, -4000, 4000, p.x)
        p.y = num(o.y, -4000, 4000, p.y)
        p.width = num(o.width, 0, 4000, p.width)
        p.scale = num(o.scale, 0.3, 3.0, p.scale)
    end
    return p
end

-- ready-made looks; single NotifyConfig.Look values override them
local PRESETS = {
    game = {
        Background = 'rgba(0, 0, 0, 0.8)', FadeEdges = true, Border = 'none', Radius = 0,
        AccentEdge = 2, AccentSide = 'screen', TitleUppercase = true,
        ShowIcons = true, IconSize = 26, Gap = 6, Animation = 'slide', FadeMs = 300,
    },
    box = {
        Background = 'rgba(0, 0, 0, 0.88)', FadeEdges = false, Border = '1px solid rgba(255, 255, 255, 0.35)', Radius = 0,
        Padding = '10px 14px', AccentEdge = 3, AccentSide = 'screen', TitleUppercase = true,
        ShowIcons = true, IconSize = 24, Gap = 8, Animation = 'slide', FadeMs = 250,
    },
    card = {
        Background = 'rgba(14, 14, 14, 0.92)', FadeEdges = false, Border = '1px solid rgba(255, 255, 255, 0.12)', Radius = 8,
        Padding = '12px 16px', AccentEdge = 3, AccentSide = 'top', TitleUppercase = false,
        ShowIcons = true, IconSize = 24, Gap = 10, Animation = 'fade', FadeMs = 250,
    },
    minimal = {
        Background = 'transparent', FadeEdges = false, Border = 'none', Radius = 0, Padding = '4px 6px',
        AccentEdge = 0, AccentSide = 'screen', TextShadow = '0 1px 2px #000, 0 0 6px rgba(0, 0, 0, 0.9)',
        TitleUppercase = true, ShowIcons = true, IconSize = 22, Gap = 4, Animation = 'fade', FadeMs = 300,
    },
}
local LOOK_KEYS = { 'Background', 'FadeEdges', 'Border', 'Radius', 'Padding', 'AccentEdge', 'AccentSide', 'TextColor',
    'TitleColor', 'DimColor', 'TextShadow', 'TitleUppercase', 'TitleFont', 'BodyFont', 'TextSize', 'TitleSize',
    'ShowIcons', 'IconSize', 'Gap', 'Animation', 'FadeMs' }
local LOOK_TEXT = { 'Background', 'Border', 'Padding', 'TextColor', 'TitleColor', 'DimColor', 'TextShadow', 'TitleFont', 'BodyFont' }
local LOOK_NUM = { 'Radius', 'AccentEdge', 'TextSize', 'TitleSize', 'IconSize', 'Gap', 'FadeMs' }
local SIDES = { screen = true, left = true, right = true, top = true, bottom = true }

local function lookOf()
    local L = type(Cfg.Look) == 'table' and Cfg.Look or {}
    local base = PRESETS[type(L.Preset) == 'string' and L.Preset:lower() or 'game'] or PRESETS.game
    local out = {}
    for _, k in ipairs(LOOK_KEYS) do
        local v = L[k]
        if v == nil then v = base[k] end
        out[k] = v
    end
    -- these become CSS values: keep them plain
    for _, k in ipairs(LOOK_TEXT) do
        if type(out[k]) ~= 'string' or out[k] == '' or out[k]:find('[;{}<>]') then out[k] = nil end
    end
    for _, k in ipairs(LOOK_NUM) do out[k] = tonumber(out[k]) end
    if out.Animation ~= 'slide' and out.Animation ~= 'fade' and out.Animation ~= 'none' then out.Animation = 'slide' end
    if not SIDES[out.AccentSide] then out.AccentSide = 'screen' end
    return out
end

local function layout()
    local l = { cyrillic = _LCode and _LCode() == 'ru' or false, look = lookOf() }
    for style in pairs(STYLES) do l[style] = placeOf(style) end
    return l
end

-- ------------------------------------------------------------
-- Notify
-- ------------------------------------------------------------
--- Turns any accepted call shape into one data table.
local function normalize(a, b, c)
    if type(a) == 'table' then
        local d = {}
        for k, v in pairs(a) do d[k] = v end
        -- ox_lib / QB shapes: description, caption
        d.text = d.text or d.description or d.message
        d.title = d.title or d.caption
        return d
    end
    return { text = a, type = b, duration = c }
end

local function notify(a, b, c)
    local d = normalize(a, b, c)
    local text, title = str(d.text), str(d.title)
    if not text and not title then return nil end

    local ntype = resolveType(d.type)
    local style = resolveStyle(d.style)
    local tdef = Cfg.Types[ntype]
    local duration = resolveDuration(d.duration, style)

    if not title and tdef.title then title = _L('notify_title_' .. ntype) end

    -- id: caller's own id (so the server can clear it later) or a new one
    local id = d.id
    local key = table.concat({ style, ntype, title or '', text or '' }, '\31')
    local now = GetGameTimer()
    local prev = Cfg.Dedupe and shown[key]
    local repeated = false
    if id == nil and prev and prev.untilAt > now then
        id, repeated = prev.id, true
    elseif id == nil then
        nextId = nextId + 1
        id = nextId
    end
    if byId[id] and byId[id] ~= key then shown[byId[id]] = nil end
    shown[key] = { id = id, untilAt = duration < 0 and math.huge or now + duration }
    byId[id] = key

    -- icon: game texture (only when enabled, see config) else a sign
    local glyph = tdef.icon
    local img
    if type(d.iconDict) == 'string' and d.iconDict ~= '' then
        if Cfg.GameIcons and type(d.icon) == 'string' and d.icon ~= '' then
            img = ('https://nui-img/%s/%s'):format(d.iconDict, d.icon) -- UNVERIFIED in RedM
        end
    else
        glyph = resolveGlyph(d.icon, glyph)
    end

    -- sound: the call's own, else the banner's, else the type's (not again for a repeat)
    if not repeated and d.sound ~= false then
        local name, set = soundPair(d.sound)
        if not name and style == 'banner' then name, set = soundPair(Cfg.Styles.banner.sound) end
        if not name then name, set = soundPair(tdef.sound) end
        playSound(name, set)
    end

    SendNUIMessage({
        action = 'notify',
        layout = layout(),
        n = {
            id = id, style = style, type = ntype,
            title = title, text = text,
            icon = glyph, img = img,
            color = resolveColor(d.color, tdef.color),
            duration = duration,
        },
    })
    return id
end

local function clear(id)
    if id == nil then return end
    local key = byId[id]
    if key then shown[key] = nil; byId[id] = nil end
    SendNUIMessage({ action = 'clear', id = id })
end

local function clearAll()
    shown, byId = {}, {}
    SendNUIMessage({ action = 'clearAll' })
end

MULTI.Notify = notify
MULTI.ClearNotify = clear
MULTI.ClearAllNotify = clearAll

exports('Notify', notify)
exports('ClearNotify', clear)
exports('ClearAll', clearAll)

-- ------------------------------------------------------------
-- In-game layout editor (/notifylayout): drag, wheel = size, Shift + wheel = width
-- ------------------------------------------------------------
local editing = false
local ED = type(Cfg.Editor) == 'table' and Cfg.Editor or {}

local function editorWords()
    local w = {}
    for _, k in ipairs({ 'help', 'save', 'cancel', 'reset', 'toast', 'tip', 'objective', 'banner',
        'sample_title', 'sample_text', 'sample_tip', 'sample_objective', 'sample_banner', 'sample_banner_text' }) do
        w[k] = _L('notify_editor_' .. k)
    end
    return w
end

local function openEditor()
    if editing then return end
    editing = true
    SendNUIMessage({ action = 'editor', layout = layout(), server = (function()
        local s = {}
        for style in pairs(STYLES) do s[style] = placeOf(style, true) end
        return s
    end)(), words = editorWords() })
    SetNuiFocus(true, true)
end

local function closeEditor()
    editing = false
    SetNuiFocus(false, false)
end

--- the saved layout as lines for NotifyConfig.Styles (F8 console), so an owner can make it everyone's default
local function printConfig(t)
    print('^5[MULTIcore] your notification layout, for config_notify.lua (NotifyConfig.Styles):^7')
    for _, style in ipairs({ 'toast', 'tip', 'objective', 'banner' }) do
        local p = t[style]
        if p then
            print(('    %s: position = \'%s\', offsetX = %d, offsetY = %d, width = %d, scale = %.2f,'):format(
                style, p.position, p.x, p.y, p.width, p.scale))
        end
    end
end

RegisterNUICallback('notifyEditor:save', function(data, cb)
    cb('ok')
    if not editing or type(data) ~= 'table' then return closeEditor() end
    local t = {}
    for style in pairs(STYLES) do
        local o = data[style]
        if type(o) == 'table' and POSITIONS[o.position] then
            t[style] = {
                position = o.position,
                x = math.floor(num(o.x, -4000, 4000, 0) + 0.5),
                y = math.floor(num(o.y, -4000, 4000, 0) + 0.5),
                width = math.floor(num(o.width, 0, 4000, 0) + 0.5),
                scale = math.floor(num(o.scale, 0.3, 3.0, 1.0) * 100 + 0.5) / 100,
            }
        end
    end
    mine = t
    SetResourceKvp(KVP, json.encode(t))
    closeEditor()
    printConfig(t)
    notify({ text = _L('notify_editor_saved'), type = 'success' })
end)

RegisterNUICallback('notifyEditor:cancel', function(_, cb)
    cb('ok')
    closeEditor()
end)

if ED.Command then
    RegisterCommand(ED.Command, function() openEditor() end, ED.Players == false)
end
if ED.ResetCommand then
    RegisterCommand(ED.ResetCommand, function()
        mine = {}
        DeleteResourceKvp(KVP)
        notify({ text = _L('notify_editor_reset_done'), type = 'info' })
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and editing then SetNuiFocus(false, false) end
end)

exports('OpenNotifyLayout', openEditor)

RegisterNetEvent('MULTIcore:notify', function(a, b, c) notify(a, b, c) end)
RegisterNetEvent('MULTIcore:notify:clear', function(id)
    if id == nil then clearAll() else clear(id) end
end)

-- ------------------------------------------------------------
-- RSG: RSGCore.Functions.Notify (client)
-- Accepted shapes, as rsg-core's own function takes them:
--   Notify({ title, description, type, duration, icon })   ox_lib table
--   Notify(title, { ... })                                  table as 2nd argument
--   Notify(text, type, duration)                            older QB style
--   Notify(title, text, type, duration, icon)               rsg-core 2.x
-- QB-style tables { text = , caption = } work too.
-- ------------------------------------------------------------
local function rsgType(t)
    t = type(t) == 'string' and t:lower() or nil
    return t and Cfg.RSGTypes[t] or t
end

local function fromRSG(title, text, ntype, duration, icon)
    if type(text) == 'table' then title = text end
    if type(title) == 'table' then
        local d = normalize(title)
        d.type = rsgType(d.type)
        d.style = d.style or Cfg.RSGStyle
        return notify(d)
    end
    if type(text) == 'string' and Cfg.RSGTypes[text:lower()] and (ntype == nil or type(ntype) == 'number') then
        return notify({ text = title, type = rsgType(text), duration = ntype, style = Cfg.RSGStyle })
    end
    if text == nil then
        return notify({ text = title, type = rsgType(ntype), duration = duration, icon = icon, style = Cfg.RSGStyle })
    end
    return notify({ title = title, text = text, type = rsgType(ntype), duration = duration, icon = icon, style = Cfg.RSGStyle })
end

if Cfg.RouteRSG then
    if RSGCore and RSGCore.Functions then
        RSGCore.Functions.Notify = fromRSG
    end
    -- older RSG / QB scripts: TriggerClientEvent('RSGCore:Notify', src, text, type, length)
    RegisterNetEvent('RSGCore:Notify', function(text, ntype, length)
        fromRSG(text, ntype, length)
    end)
end
