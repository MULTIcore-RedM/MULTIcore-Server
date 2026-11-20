--[[
    Locale: locales/<lang>.json, English as the fallback for missing keys.
    <lang> = Config.Locale, or (when that is '') the server's  setr multicore_locale  convar, else 'en'.
    L(key, ...) -> text with %s / %d filled in (a bad format never errors, the raw text is returned).
]]
local RES = GetCurrentResourceName()
local strings, fallback = {}, {}

local function load(lang)
    local raw = LoadResourceFile(RES, ('locales/%s.json'):format(lang))
    if not raw then return {} end
    local ok, data = pcall(json.decode, raw)
    return (ok and type(data) == 'table') and data or {}
end

local function language()
    local lang = Config.Locale
    if type(lang) ~= 'string' or lang == '' then lang = GetConvar('multicore_locale', '') end
    lang = tostring(lang or ''):lower()
    if lang == '' or not lang:match('^[%a%-]+$') then lang = 'en' end
    return lang
end

fallback = load('en')
local lang = language()
strings = lang ~= 'en' and load(lang) or fallback

function L(key, ...)
    local s = strings[key] or fallback[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end

---Every string (the NUI gets them once on open).
function LocaleTable()
    local out = {}
    for k, v in pairs(fallback) do out[k] = v end
    for k, v in pairs(strings) do out[k] = v end
    return out
end
