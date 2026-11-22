-- ============================================================
-- MULTIcore :: shared language helper
-- Every MULTI script loads this file and its own locales folder:
--
--   shared_scripts {
--       '@MULTIcore/shared/i18n.lua',
--       'config.lua',
--       'locales/*.lua',
--   }
--
-- A locale file looks like:
--   Locales = Locales or {}
--   Locales['en'] = {
--       ['welcome'] = 'Welcome, %s',
--   }
--
-- Language choice (first one set wins):
--   1. Config.Locale in the script's config.lua  (e.g. 'de')
--   2. MULTIConfig.Language in MULTIcore/config_multi.lua (all MULTI scripts at once;
--      MULTIcore copies it to the convar multicore_locale; '' = server.cfg setr multicore_locale)
--   3. 'en'
-- Languages shipped: en de fr es pt-br it pl ru nl tr ro cs hu uk bg el sv da no fi pt sk hr sr sl zh ja ko ar id vi th
-- A missing line falls back to English, then to the key itself, so a
-- half-finished translation never breaks a script.
--
-- In Lua:  _L('welcome', name)
-- For NUI: send _LT() (the whole table for the chosen language, with
--          English filling any gaps) and look lines up in JavaScript.
-- ============================================================

Locales = Locales or {}

local function lang()
    local cfg = rawget(_G, 'Config')
    if type(cfg) == 'table' and type(cfg.Locale) == 'string' and cfg.Locale ~= '' then return cfg.Locale end
    local cv = GetConvar('multicore_locale', '')
    if cv ~= '' then return cv end
    return 'en'
end

--- One translated line. Extra arguments fill %s / %d markers.
function _L(key, ...)
    local l = Locales[lang()]
    local text = (l and l[key]) or (Locales.en and Locales.en[key]) or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, text, ...)
        if ok then return out end
    end
    return text
end

--- The whole table for the chosen language (English fills gaps), for NUI pages.
function _LT()
    local out = {}
    for k, v in pairs(Locales.en or {}) do out[k] = v end
    for k, v in pairs(Locales[lang()] or {}) do out[k] = v end
    return out
end

--- The language code in use (for NUI, e.g. to switch to the plain font preset).
function _LCode() return lang() end

-- Languages whose letters the game fonts do not have: NUI pages swap to the plain
-- font preset (class mc-cyrillic) for these.
local PLAIN = { ru = true, uk = true, bg = true, el = true, zh = true, ja = true, ko = true, ar = true, th = true, vi = true }

--- true when the language in use needs the plain font preset (Cyrillic, Greek, Asian, Arabic ...).
function _LPlainFont(code) return PLAIN[code or lang()] == true end
