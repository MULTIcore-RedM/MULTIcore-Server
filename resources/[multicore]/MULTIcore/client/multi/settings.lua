-- ============================================================
-- MULTIcore :: in-game settings (client)
-- Settings registered with client = true reach every player through
-- GlobalState['mcset:<key>'] (server/multi/settings.lua). Scripts use
-- @MULTIcore/lib/settings.lua; this export is for quick reads.
--   exports.MULTIcore:GetSetting('MULTIcore.Density.Peds')
-- ============================================================

exports('GetSetting', function(key)
    if type(key) ~= 'string' then return nil end
    return GlobalState['mcset:' .. key]
end)
