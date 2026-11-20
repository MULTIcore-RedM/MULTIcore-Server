local dict = {}

local function interpolate(str, ...)
    local count = select('#', ...)
    if count == 0 or type(str) ~= 'string' then
        return str
    end

    local first = select(1, ...)
    if count == 1 and type(first) == 'table' then
        return (str:gsub('{([%w_]+)}', function(key)
            local value = first[key]
            if value == nil then
                return '{' .. key .. '}'
            end
            return tostring(value)
        end))
    end

    return str:format(...)
end

function L(key, ...)
    local value = dict[key]
    if type(value) ~= 'string' then
        return key
    end
    return interpolate(value, ...)
end

function GetLocaleDict()
    return dict
end

-- Config.Locale, else MULTIcore's  setr multicore_locale "<code>", else ox_lib's, else English
local lang = Config.Locale
if type(lang) ~= 'string' or lang == '' then
    lang = GetConvar('multicore_locale', '')
    if lang == '' then lang = GetConvar('ox:locale', 'en') end
end

local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
if not raw then
    raw = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
end

local base = lang ~= 'en' and LoadResourceFile(GetCurrentResourceName(), 'locales/en.json') or nil
if base then
    local ok, decoded = pcall(json.decode, base)
    if ok and type(decoded) == 'table' then dict = decoded end
end

if raw then
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        for k, v in pairs(decoded) do dict[k] = v end
    else
        print('[MULTIinventory] Failed to parse locale file for "' .. tostring(lang) .. '".')
    end
end
