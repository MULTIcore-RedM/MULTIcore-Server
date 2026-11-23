-- ============================================================
-- MULTIcore :: one language for every MULTI script
-- MULTIConfig.Language (config_multi.lua) is copied to the replicated
-- convar multicore_locale, which every MULTI script reads (server and
-- client). '' leaves whatever server.cfg sets with setr multicore_locale.
-- ============================================================
local KNOWN = {}
for code in ('en de fr es pt-br it pl ru nl tr ro cs hu uk bg el sv da no fi pt sk hr sr sl zh ja ko ar id vi th'):gmatch('%S+') do KNOWN[code] = true end

local lang = MULTIConfig and MULTIConfig.Language
if type(lang) == 'string' and lang ~= '' then
    lang = lang:lower()
    if not KNOWN[lang] then
        print(('[MULTIcore] Language "%s" is not one MULTI scripts ship; missing lines show in English.'):format(lang))
    end
    SetConvarReplicated('multicore_locale', lang)
end

-- ============================================================
-- MULTIConfig.UIPreset -> replicated convar multicore_ui_preset, which every
-- MULTI page reads through html/theme/preset.js. '' leaves server.cfg's
-- setr multicore_ui_preset.
-- ============================================================
local PRESETS = { classic = true, parchment = true, modern = true }
local preset = MULTIConfig and MULTIConfig.UIPreset
if type(preset) == 'string' and preset ~= '' then
    preset = preset:lower()
    if not PRESETS[preset] then
        print(('[MULTIcore] UIPreset "%s" is not classic, parchment or modern; classic is used.'):format(preset))
        preset = 'classic'
    end
    SetConvarReplicated('multicore_ui_preset', preset)
end
