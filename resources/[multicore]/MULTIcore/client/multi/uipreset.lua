-- ============================================================
-- MULTIcore :: UI preset for every MULTI page
-- html/theme/preset.js (loaded by each page) asks here which look the
-- server uses: MULTIConfig.UIPreset -> convar multicore_ui_preset.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================
local PRESETS = { classic = true, parchment = true, modern = true }

local function current()
    local p = GetConvar('multicore_ui_preset', 'classic'):lower()
    return PRESETS[p] and p or 'classic'
end

RegisterNUICallback('mcUiPreset', function(_, cb)
    cb({ preset = current() })
end)

exports('GetUIPreset', current)
