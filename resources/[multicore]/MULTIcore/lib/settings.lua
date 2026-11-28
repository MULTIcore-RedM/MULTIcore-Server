-- ============================================================
-- MULTIcore :: settings helper for scripts
-- Lets a server owner change a script's values in game (MULTIadmin, Settings page),
-- live, without editing files or restarting. The config file stays the default.
--
-- fxmanifest.lua:
--   shared_scripts { '@MULTIcore/shared/i18n.lua', 'config.lua', 'locales/*.lua', '@MULTIcore/lib/settings.lua', 'settings.lua' }
--
-- settings.lua (the same file runs on the server and on the client):
--   MCSettings.Register({
--       { key = 'MyScript.Price', type = 'number', default = Config.Price, min = 0, max = 100, step = 0.05,
--         label = 'set_price', category = 'setcat_prices',      -- locale keys of this script
--         apply = function(v) Config.Price = v end },
--       { key = 'MyScript.Open', type = 'bool', default = Config.Open, client = true,
--         label = 'set_open', category = 'setcat_hours',
--         apply = function(v) Config.Open = v end },          -- client = true: also runs on every player's PC
--   })
--
-- type: 'number' (min, max, step, integer = true), 'bool', 'string' (maxLength), 'choice' (choices = { { value, label } })
-- apply(value) runs at once with the value in use, and again on every change or reset.
-- Server: apply runs for every setting. Client: only for settings with client = true.
-- Keys must be unique on the server: start them with your resource name.
-- Full description: docs/API.md, "In-game settings".
-- ============================================================

MCSettings = MCSettings or {}

local binds = {}
local defs = {}

local function text(key)
    if key == nil then return nil end
    if type(_L) == 'function' then return _L(key) end
    return key
end

if IsDuplicityVersion() then
    local function send()
        local clean = {}
        for _, d in ipairs(defs) do
            local c = {}
            for k, v in pairs(d) do
                if k ~= 'apply' then c[k] = v end
            end
            c.label = text(d.label)
            c.help = text(d.help)
            c.category = text(d.category)
            c.unit = text(d.unit)
            if d.choices then
                c.choices = {}
                for i, ch in ipairs(d.choices) do
                    if type(ch) == 'table' then c.choices[i] = { value = ch.value, label = text(ch.label or tostring(ch.value)) }
                    else c.choices[i] = { value = ch, label = tostring(ch) } end
                end
            end
            clean[#clean + 1] = c
        end
        local ok, values = pcall(function() return exports.MULTIcore:RegisterSettings(clean) end)
        if not ok or type(values) ~= 'table' then return end
        for key, v in pairs(values) do
            local fn = binds[key]
            if fn then pcall(fn, v) end
        end
    end

    --- Registers settings (see the top of this file). Can be called more than once.
    function MCSettings.Register(list)
        for _, d in ipairs(list or {}) do
            if type(d) == 'table' and type(d.key) == 'string' then
                local at = #defs + 1
                for i, old in ipairs(defs) do
                    if old.key == d.key then at = i break end   -- the same key again replaces it
                end
                defs[at] = d
                binds[d.key] = d.apply
            end
        end
        send()
    end

    --- The value in use (also for settings of other scripts).
    function MCSettings.Get(key) return exports.MULTIcore:GetSetting(key) end

    AddEventHandler('MULTIcore:settings:changed', function(key, value)
        local fn = binds[key]
        if fn then
            local ok, err = pcall(fn, value)
            if not ok then print(('^1[%s] setting %s could not be applied: %s^7'):format(GetCurrentResourceName(), key, tostring(err))) end
        end
    end)

    -- MULTIcore restarted: tell it the settings again
    AddEventHandler('onResourceStart', function(res)
        if res == 'MULTIcore' and #defs > 0 then send() end
    end)
else
    local function follow(d)
        local stateName = 'mcset:' .. d.key
        local now = GlobalState[stateName]
        if now ~= nil then pcall(d.apply, now) end
        AddStateBagChangeHandler(stateName, 'global', function(_, _, value)
            if value ~= nil then
                local ok, err = pcall(d.apply, value)
                if not ok then print(('[%s] setting %s could not be applied: %s'):format(GetCurrentResourceName(), d.key, tostring(err))) end
            end
        end)
    end

    --- Client side of the same call: settings with client = true follow the server's value.
    function MCSettings.Register(list)
        for _, d in ipairs(list or {}) do
            if type(d) == 'table' and type(d.key) == 'string' and d.client and type(d.apply) == 'function' then
                defs[#defs + 1] = d
                follow(d)
            end
        end
    end

    --- The value in use for a setting with client = true (nil when the server has not sent it).
    function MCSettings.Get(key) return GlobalState['mcset:' .. key] end
end
