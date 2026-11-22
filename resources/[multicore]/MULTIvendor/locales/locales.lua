-- Locale helper. Loaded after all locale files.
-- Uses Config.Locale with English fallback, supports %s formatting.
function _L(key, ...)
    local locale = Locales[Config.Locale] or Locales['en']
    local str = locale and locale[key] or ('MISSING: ' .. key)
    if ... then
        return string.format(str, ...)
    end
    return str
end