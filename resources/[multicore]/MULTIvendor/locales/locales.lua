-- Locale helper. Loaded after all locale files.
-- Language: Config.Locale, else MULTIcore's language (setr multicore_locale), else English.
-- A missing line falls back to English. Supports %s formatting.
function VendorLang()
    local l = Config.Locale
    if type(l) ~= 'string' or l == '' then l = GetConvar('multicore_locale', '') end
    if l == '' then l = 'en' end
    return l
end

function _L(key, ...)
    local locale = Locales[VendorLang()] or {}
    local str = locale[key] or (Locales['en'] and Locales['en'][key]) or ('MISSING: ' .. key)
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, str, ...)
        if ok then return out end
    end
    return str
end
