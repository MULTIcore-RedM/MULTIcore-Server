-- ============================================================
-- MULTIhelpers :: NUI focus
-- One page draws menus, input boxes and progress bars. Each part says
-- what it needs (keyboard, cursor) and this file sets the focus once.
-- ============================================================

local wants = {}   -- [part] = { keyboard = bool, cursor = bool, keepInput = bool } or nil

local current = { keyboard = false, cursor = false, keepInput = false }

function Helpers.SetFocus(part, want)
    wants[part] = want
    local kb, cur, keep = false, false, false
    local anyKeepOff = false
    for _, w in pairs(wants) do
        if w.keyboard then
            kb = true
            if w.keepInput then keep = true else anyKeepOff = true end
        end
        if w.cursor then cur = true end
    end
    -- keep game input only when every part that holds the keyboard allows it
    keep = keep and not anyKeepOff
    if kb ~= current.keyboard or cur ~= current.cursor then
        SetNuiFocus(kb or cur, cur)
    end
    if keep ~= current.keepInput then
        SetNuiFocusKeepInput(keep)
    end
    current = { keyboard = kb, cursor = cur, keepInput = keep }
end

function Helpers.Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

--- Play a configured frontend sound (Config.Menu.Sounds[key]).
function Helpers.Sound(key)
    local s = Config.Menu.Sounds and Config.Menu.Sounds[key]
    if type(s) ~= 'table' then return end
    PlaySoundFrontend(s[1], s[2], true, 0)
end

-- ------------------------------------------------------------ dialog
-- One input dialog at a time, shared by vorp_inputs and menu.displayInput.
-- spec = { kind = 'input'|'yesno', header, placeholder, description, button, cancelButton,
--          inputType = 'text'|'number'|'password'|'date'|'textarea', pattern, preset,
--          title, min, max, step, minLength, maxLength, value, style }
-- cb(result) gets the typed text, or nil when cancelled ('yes' for a yes/no box).
local dialog = nil
local dialogSeq = 0

function Helpers.CloseDialog()
    local d = dialog
    if not d then return end
    dialog = nil
    Helpers.Send('dialogClose')
    Helpers.SetFocus('dialog', nil)
    if d.cb then Helpers.SafeCall(d.cb, nil) end
end

function Helpers.OpenDialog(spec, cb, owner)
    -- a new dialog replaces an open one; the old caller gets nil (cancel)
    if dialog then Helpers.CloseDialog() end
    dialogSeq = dialogSeq + 1
    dialog = { token = dialogSeq, cb = cb, owner = owner }
    spec.token = dialogSeq
    Helpers.Send('dialogOpen', spec)
    Helpers.SetFocus('dialog', { keyboard = true, cursor = true })
    return dialogSeq
end

RegisterNUICallback('dialog', function(d, reply)
    reply('ok')
    if not dialog or type(d) ~= 'table' or d.token ~= dialog.token then return end
    local cb = dialog.cb
    dialog = nil
    Helpers.Send('dialogClose')
    Helpers.SetFocus('dialog', nil)
    local result = nil
    if d.result == 'submit' then
        result = d.value
        if result == nil then result = '' end
        result = tostring(result)
    end
    if cb then CreateThread(function() Helpers.SafeCall(cb, result) end) end
end)

-- A caller stopped while its dialog is open: close it without calling back into it.
AddEventHandler('onClientResourceStop', function(res)
    if dialog and dialog.owner == res then
        dialog.cb = nil
        Helpers.CloseDialog()
    end
end)

-- Never leave the player stuck with focus if this resource stops.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end)

-- ------------------------------------------------------------ page setup
-- The page asks once it has loaded: language lines and the look settings from config.lua.
local function uiConfig()
    local m, p, i = Config.Menu, Config.Progress, Config.Inputs
    return {
        lang = _LCode(),
        text = _LT(),
        menu = {
            align = m.Align, offsetTop = m.OffsetTop, offsetSide = m.OffsetSide, width = m.Width,
            gridColumns = m.GridColumns, keyHints = m.ShowKeyHints, keys = m.Keys,
            maxVisibleItems = m.MaxVisibleItems,
        },
        inputs = { width = i.Width },
        progress = {
            color = p.Color, trackColor = p.TrackColor, width = p.Width, circleSize = p.CircleSize,
            bottom = p.Bottom, showPercent = p.ShowPercent, theme = p.DefaultTheme,
        },
    }
end

RegisterNUICallback('ready', function(_, reply)
    reply(uiConfig())
end)
