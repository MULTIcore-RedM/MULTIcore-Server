-- ============================================================
-- MULTIcore :: small VORP extras, client (docs/COMPAT_SURVEY.md gap 10)
-- vorp:showUi (bool) is VORP's "show / hide the HUD" event. HUD scripts
-- listen for it; MULTIcore also passes it to MULTIhud when that runs, so
-- MULTI's own HUD hides and shows with the others. Without MULTIhud it
-- does nothing here (the other listeners still get it).
-- ============================================================

RegisterNetEvent('vorp:showUi')
AddEventHandler('vorp:showUi', function(show)
    if GetResourceState('MULTIhud') ~= 'started' then return end
    local visible = show == true or show == 1 or show == 'true'
    pcall(function() exports.MULTIhud:SetVisible(visible) end)
end)
