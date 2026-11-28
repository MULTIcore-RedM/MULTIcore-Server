-- ============================================================
-- MULTIadmin :: in-game settings (Settings page)
-- Lists every setting MULTI scripts registered with MULTIcore
-- (exports.MULTIcore:RegisterSettings, docs/API.md) and changes or resets
-- them. Permission (Config.ActionLevel) is checked by the action callback
-- before these run; MULTIcore checks the value (type, min, max) again,
-- saves it and applies it live. Every change is logged.
-- ============================================================

local H = Admin.Handlers
local MC = exports.MULTIcore

local function list()
    local ok, rows = pcall(function() return MC:GetSettings() end)
    return ok and type(rows) == 'table' and rows or {}
end

local function find(key)
    for _, r in ipairs(list()) do
        if r.key == key then return r end
    end
end

local function show(r, v)
    if r.type == 'bool' then return _L(v and 'set_on' or 'set_off') end
    if r.type == 'choice' then
        for _, c in ipairs(r.choices or {}) do
            if c.value == v then return c.label end
        end
    end
    return tostring(v)
end

local function errText(r, err)
    if err == 'too_low' then return _L('serr_too_low', show(r, r.min)) end
    if err == 'too_high' then return _L('serr_too_high', show(r, r.max)) end
    local key = 'serr_' .. tostring(err)
    local text = _L(key)
    return text ~= key and text or _L('err_failed')
end

H.settings = function()
    return true, nil, list()
end

H.settings_set = function(src, data)
    local key = type(data.key) == 'string' and data.key or ''
    local r = find(key)
    if not r then return false, _L('serr_unknown') end
    local value = data.value
    if type(value) == 'string' and #value > 400 then value = value:sub(1, 400) end
    local ok, err, newValue = MC:SetSetting(key, value, Admin.Who(src))
    if not ok then
        Admin.Log(src, 'setting (refused)', ('%s = %s (%s)'):format(key, tostring(value), tostring(err)))
        return false, errText(r, err)
    end
    Admin.Log(src, 'setting', ('%s: %s -> %s'):format(key, show(r, r.value), show(r, newValue)))
    return true, _L('ok_setting', r.label, show(r, newValue)), list()
end

H.settings_reset = function(src, data)
    local key = type(data.key) == 'string' and data.key or ''
    local r = find(key)
    if not r then return false, _L('serr_unknown') end
    local ok, err, newValue = MC:ResetSetting(key, Admin.Who(src))
    if not ok then return false, errText(r, err) end
    Admin.Log(src, 'setting reset', ('%s: %s -> file value %s'):format(key, show(r, r.value), show(r, newValue)))
    return true, _L('ok_setting_reset', r.label, show(r, newValue)), list()
end
