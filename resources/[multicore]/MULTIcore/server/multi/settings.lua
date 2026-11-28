-- ============================================================
-- MULTIcore :: in-game settings
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
--
-- Scripts register the values a server owner may change while the server
-- runs (world density, prices, wages ...). The value in the script's config
-- file is the default; a value changed in game (MULTIadmin, Settings page)
-- is saved in the table `multicore_settings` and wins on every start until
-- it is reset to the file value.
--
-- Scripts use @MULTIcore/lib/settings.lua (MCSettings.Register), which
-- calls the exports below and applies every change live.
--
--   exports.MULTIcore:RegisterSettings(defs)          -> { [key] = value in use }
--   exports.MULTIcore:GetSetting(key)                 -> value in use
--   exports.MULTIcore:SetSetting(key, value, by)      -> true | false, error
--   exports.MULTIcore:ResetSetting(key, by)           -> true | false, error
--   exports.MULTIcore:GetSettings()                   -> list for a settings page
--   exports.MULTIcore:CanChangeSettings(src)          -> true | false
--
-- `by`: a player source (checked: MULTIcore admin or ace multicore.settings),
-- or a text naming who changed it (a script that did its own check, e.g. MULTIadmin).
--
-- Every change fires the server event  MULTIcore:settings:changed (key, value, by)
-- and, for settings with client = true, sets GlobalState['mcset:<key>'] so
-- every player (also those who join later) gets it.
-- ============================================================

MULTI.Settings = { defs = {}, stored = {}, loaded = false, order = 0 }
local S = MULTI.Settings

local TYPES = { number = true, bool = true, string = true, choice = true }
local MAX_STRING = 200

local function stateKey(key) return 'mcset:' .. key end

local function cleanText(s, max)
    return tostring(s or ''):gsub('[%c<>]', ''):sub(1, max or MAX_STRING)
end

local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 1e-9 end
    return a == b
end

--- Checks a value against a setting. Returns the cleaned value, or nil and an error key.
local function validate(def, value)
    local t = def.type
    if t == 'number' then
        local n = tonumber(value)
        if not n or n ~= n or n == math.huge or n == -math.huge then return nil, 'not_number' end
        if def.integer then n = math.floor(n + 0.5) end
        if def.min and n < def.min - 1e-9 then return nil, 'too_low' end
        if def.max and n > def.max + 1e-9 then return nil, 'too_high' end
        return n
    elseif t == 'bool' then
        if value == true or value == 'true' or value == 1 then return true end
        if value == false or value == 'false' or value == 0 then return false end
        return nil, 'not_bool'
    elseif t == 'string' then
        if type(value) ~= 'string' and type(value) ~= 'number' then return nil, 'not_text' end
        local s = cleanText(value, def.maxLength or MAX_STRING)
        if def.minLength and #s < def.minLength then return nil, 'too_short' end
        return s
    elseif t == 'choice' then
        for _, c in ipairs(def.choices or {}) do
            if same(c.value, value) or tostring(c.value) == tostring(value) then return c.value end
        end
        return nil, 'not_choice'
    end
    return nil, 'bad_type'
end
S.Validate = validate

--- The value in use: the saved one when it is still valid, else the file value.
local function current(def)
    local row = S.stored[def.key]
    if row ~= nil then
        local v = validate(def, row.value)
        if v ~= nil then return v, true end
    end
    return def.default, false
end

local function publish(def, value, by)
    if def.client then GlobalState[stateKey(def.key)] = value end
    TriggerEvent('MULTIcore:settings:changed', def.key, value, by)
end

-- ------------------------------------------------------------
-- database
-- ------------------------------------------------------------
local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `multicore_settings` (
  `key` VARCHAR(100) NOT NULL,
  `value` TEXT NOT NULL,
  `changed_by` VARCHAR(255) DEFAULT NULL,
  `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local function decode(text)
    local ok, d = pcall(json.decode, text or '')
    if ok and type(d) == 'table' then return d.v end
    return nil
end

--- Reads every saved value. Settings already registered get theirs at once.
function S.Load()
    MULTI.Schema.Wait()
    local ok, err = pcall(MySQL.query.await, TABLE_SQL)
    if not ok then print(('^1[MULTIcore] settings table setup failed: %s^7'):format(tostring(err))) end
    local rows = {}
    if ok then rows = MySQL.query.await('SELECT `key`, `value`, `changed_by`, UNIX_TIMESTAMP(`changed_at`) AS `at` FROM `multicore_settings`') or {} end
    S.stored = {}
    for _, r in ipairs(rows) do
        S.stored[r.key] = { value = decode(r.value), by = r.changed_by, at = tonumber(r.at) }
    end
    S.loaded = true
    for _, def in pairs(S.defs) do
        local v, saved = current(def)
        if saved and not same(v, def.default) then publish(def, v, 'database') end
        if S.stored[def.key] and not saved then
            print(('^3[MULTIcore] saved setting %s no longer fits (%s), the file value is used^7'):format(def.key, tostring(S.stored[def.key].value)))
        end
    end
    print(('[MULTIcore] in-game settings ready (%d saved values)'):format(#rows))
end

local function save(key, value, by)
    MySQL.query.await('INSERT INTO `multicore_settings` (`key`, `value`, `changed_by`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `changed_by` = VALUES(`changed_by`)',
        { key, json.encode({ v = value }), by })
    S.stored[key] = { value = value, by = by, at = os.time() }
end

local function forget(key)
    MySQL.query.await('DELETE FROM `multicore_settings` WHERE `key` = ?', { key })
    S.stored[key] = nil
end

-- ------------------------------------------------------------
-- register
-- ------------------------------------------------------------

--- Adds (or refreshes) settings. defs = list of
---   { key, type = 'number'|'bool'|'string'|'choice', default, min, max, step, integer,
---     maxLength, choices = { { value, label } }, label, help, category, unit, client }
--- Labels are plain text (the script translates them). Returns { [key] = value in use }.
function S.Register(resource, defs)
    resource = cleanText(resource or 'unknown', 64)
    local out = {}
    if type(defs) ~= 'table' then return out end
    for _, d in ipairs(defs) do
        local key = type(d) == 'table' and type(d.key) == 'string' and cleanText(d.key, 100) or nil
        if not key or key == '' or not TYPES[d.type] then
            print(('^3[MULTIcore] %s: setting %s skipped (needs key and type number/bool/string/choice)^7'):format(resource, tostring(key)))
        else
            S.order = S.order + 1
            local def = {
                key = key, resource = resource, type = d.type,
                min = tonumber(d.min), max = tonumber(d.max), step = tonumber(d.step), integer = d.integer == true,
                maxLength = tonumber(d.maxLength), minLength = tonumber(d.minLength),
                label = cleanText(d.label or key, 120), help = d.help and cleanText(d.help, 300) or nil,
                category = cleanText(d.category or '', 80), unit = d.unit and cleanText(d.unit, 20) or nil,
                client = d.client == true, order = tonumber(d.order) or S.order,
            }
            if d.type == 'choice' then
                def.choices = {}
                for _, c in ipairs(d.choices or {}) do
                    if type(c) == 'table' then def.choices[#def.choices + 1] = { value = c.value, label = cleanText(c.label or tostring(c.value), 80) }
                    else def.choices[#def.choices + 1] = { value = c, label = cleanText(tostring(c), 80) } end
                end
            end
            -- the file value must itself fit, or the setting cannot be reset to it
            local default = validate(def, d.default)
            if default == nil then
                print(('^3[MULTIcore] %s: setting %s skipped (file value %s does not fit its own limits)^7'):format(resource, key, tostring(d.default)))
            else
                def.default = default
                S.defs[key] = def
                local v = current(def)
                if def.client then GlobalState[stateKey(key)] = v end
                out[key] = v
            end
        end
    end
    return out
end

-- a script that stops takes its settings off the list (saved values stay in the table)
AddEventHandler('onResourceStop', function(res)
    for key, def in pairs(S.defs) do
        if def.resource == res then S.defs[key] = nil end
    end
end)

-- ------------------------------------------------------------
-- change / reset
-- ------------------------------------------------------------

--- True when this player may change settings: a MULTIcore admin or ace multicore.settings. Console = yes.
function S.CanChange(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or not GetPlayerName(src) then return false end
    if IsPlayerAceAllowed(tostring(src), 'multicore.settings') then return true end
    return MULTI.Api and MULTI.Api.IsAdmin(src) == true or false
end

--- who: a source is checked; a text is trusted (the caller did its own check).
local function byText(by)
    if type(by) == 'number' then
        if by == 0 then return true, 'console' end
        if not S.CanChange(by) then return false end
        local name = GetPlayerName(by) or '?'
        local lic = GetPlayerIdentifierByType(by, 'license') or '?'
        return true, ('%s [%d] (%s)'):format(name, by, lic)
    end
    if by == nil then return true, ('script %s'):format(GetInvokingResource() or GetCurrentResourceName()) end
    return true, cleanText(by, 255)
end

local function show(v)
    if type(v) == 'string' then return ('"%s"'):format(v) end
    return tostring(v)
end

function S.Set(key, value, by)
    local def = S.defs[key or '']
    if not def then return false, 'unknown' end
    local allowed, who = byText(by)
    if not allowed then
        print(('^3[MULTIcore] setting %s: change refused for player %s (not allowed)^7'):format(key, tostring(by)))
        return false, 'not_allowed'
    end
    local v, err = validate(def, value)
    if v == nil then return false, err end
    local old = current(def)
    local ok, dbErr = pcall(save, key, v, who)
    if not ok then
        print(('^1[MULTIcore] setting %s could not be saved: %s^7'):format(key, tostring(dbErr)))
        return false, 'db'
    end
    print(('[MULTIcore] setting %s: %s -> %s by %s'):format(key, show(old), show(v), who))
    publish(def, v, who)
    return true, nil, v
end

function S.Reset(key, by)
    local def = S.defs[key or '']
    if not def then return false, 'unknown' end
    local allowed, who = byText(by)
    if not allowed then
        print(('^3[MULTIcore] setting %s: reset refused for player %s (not allowed)^7'):format(key, tostring(by)))
        return false, 'not_allowed'
    end
    local old = current(def)
    local ok, dbErr = pcall(forget, key)
    if not ok then
        print(('^1[MULTIcore] setting %s could not be reset: %s^7'):format(key, tostring(dbErr)))
        return false, 'db'
    end
    print(('[MULTIcore] setting %s: %s -> file value %s by %s'):format(key, show(old), show(def.default), who))
    publish(def, def.default, who)
    return true, nil, def.default
end

function S.Get(key)
    local def = S.defs[key or '']
    if not def then return nil end
    return (current(def))
end

--- Every registered setting with its value in use, sorted by script, category and order.
function S.List()
    local out = {}
    for _, def in pairs(S.defs) do
        local v, saved = current(def)
        local row = saved and S.stored[def.key] or nil
        out[#out + 1] = {
            key = def.key, resource = def.resource, category = def.category, label = def.label, help = def.help,
            type = def.type, min = def.min, max = def.max, step = def.step, integer = def.integer, unit = def.unit,
            maxLength = def.maxLength, choices = def.choices, client = def.client, order = def.order,
            value = v, default = def.default, changed = saved and not same(v, def.default) or false,
            changedBy = row and row.by or nil, changedAt = row and row.at or nil,
        }
    end
    table.sort(out, function(a, b)
        if a.resource ~= b.resource then return a.resource < b.resource end
        if a.category ~= b.category then return a.category < b.category end
        return a.order < b.order
    end)
    return out
end

exports('RegisterSettings', function(defs) return S.Register(GetInvokingResource() or GetCurrentResourceName(), defs) end)
exports('GetSetting', S.Get)
exports('SetSetting', function(key, value, by) return S.Set(key, value, by) end)
exports('ResetSetting', function(key, by) return S.Reset(key, by) end)
exports('GetSettings', S.List)
exports('CanChangeSettings', S.CanChange)

-- self-test only: read the table again, as on a fresh start
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestReloadSettings', function() S.Load() return true end)
end

CreateThread(S.Load)

-- ------------------------------------------------------------
-- MULTIcore's own settings (labels in locales/settings_<lang>.lua)
-- ------------------------------------------------------------
local function round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end

local CORE = {}
local density = MULTIConfig.Density or {}
for i, k in ipairs({ 'Peds', 'ScenarioPeds', 'Animals', 'Vehicles', 'RandomVehicles', 'ParkedVehicles' }) do
    CORE[#CORE + 1] = {
        key = 'MULTIcore.Density.' .. k, type = 'number', default = tonumber(density[k]) or 1.0,
        min = 0.0, max = 1.0, step = 0.05, client = true, order = i,
        label = _L('set_density_' .. k:lower()), category = _L('setcat_world'),
        apply = function(v) MULTIConfig.Density = MULTIConfig.Density or {}; MULTIConfig.Density[k] = v end,
    }
end
CORE[#CORE + 1] = {
    key = 'MULTIcore.PayCheckMinutes', type = 'number', integer = true, default = tonumber(RSGConfig.Money.PayCheckTimeOut) or 10,
    min = 1, max = 120, step = 1, order = 10, unit = _L('set_unit_min'),
    label = _L('set_paycheck_minutes'), category = _L('setcat_wages'),
    apply = function(v) RSGConfig.Money.PayCheckTimeOut = v end,
}
CORE[#CORE + 1] = {
    key = 'MULTIcore.WageMultiplier', type = 'number', default = round2(tonumber(MULTIConfig.WageMultiplier) or 1.0),
    min = 0.0, max = 10.0, step = 0.05, order = 11, unit = 'x',
    label = _L('set_wage_multiplier'), category = _L('setcat_wages'),
    apply = function(v) MULTIConfig.WageMultiplier = v end,
}
CORE[#CORE + 1] = {
    key = 'MULTIcore.PayCheckSociety', type = 'bool', default = RSGConfig.Money.PayCheckSociety == true, order = 12,
    label = _L('set_paycheck_society'), category = _L('setcat_wages'),
    apply = function(v) RSGConfig.Money.PayCheckSociety = v end,
}

local coreApply = {}
local function registerCore()
    local clean = {}
    for _, d in ipairs(CORE) do
        coreApply[d.key] = d.apply
        local c = {}
        for k, v in pairs(d) do if k ~= 'apply' then c[k] = v end end
        clean[#clean + 1] = c
    end
    for key, v in pairs(S.Register(GetCurrentResourceName(), clean)) do coreApply[key](v) end
end
registerCore()
AddEventHandler('MULTIcore:settings:changed', function(key, value)
    local fn = coreApply[key]
    if fn then fn(value) end
end)
