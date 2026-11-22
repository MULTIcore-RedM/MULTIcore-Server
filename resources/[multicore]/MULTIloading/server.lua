-- Tells the loading screen which language MULTIcore uses (html/app.js reads nuiHandoverData.multicoreLang).
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local lang = GetConvar('multicore_locale', '')
    if lang ~= '' and deferrals and deferrals.handover then
        deferrals.handover({ multicoreLang = lang })
    end
end)
