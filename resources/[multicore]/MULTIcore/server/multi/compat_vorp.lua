-- ============================================================
-- MULTIcore :: small VORP extras (docs/COMPAT_SURVEY.md gap 10)
--   * exports.vorp_core:getUserByCharId(charId), called straight on the
--     export (not through GetCore) by some scripts.
--   * client event vorp:setjob (job, grade) whenever a character's job or
--     grade changes, from either kind of script. Client scripts keep their
--     own copy of the job with it.
-- Not covered here, on purpose:
--   * vorp_core:Client:AddTimeToRespawn is answered by MULTImedic.
--   * vorp:showUi is answered on the client (client/multi/compat_vorp.lua).
--   * vorp_inventory:Server:SaddleOpen is an inventory event (VORP's
--     inventory fires it when a saddlebag opens); MULTIinventory would
--     have to fire it. Nothing in MULTIcore fires it.
-- Written for MULTIcore (GPL v3); no VORP code is used.
-- ============================================================

local cfg = MULTIConfig.Compat or {}

MULTI.ExportAs('vorp_core', 'getUserByCharId', function(charId)
    return MULTI.Vorp.Core.getUserByCharId(charId)
end)

if cfg.VorpSetJobEvent ~= false then
    local seen = {}  -- [source] = { name, grade } last sent

    local function send(src, job)
        if not src or type(job) ~= 'table' then return end
        local now = { name = job.name, grade = tonumber(job.grade and job.grade.level) or 0 }
        local before = seen[src]
        seen[src] = now
        if before and before.name == now.name and before.grade == now.grade then return end
        TriggerClientEvent('vorp:setjob', src, now.name, now.grade)
    end

    AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
        local src = P.PlayerData.source
        if src then seen[src] = nil; send(src, P.PlayerData.job) end
    end)
    AddEventHandler('RSGCore:Server:OnJobUpdate', function(src, job) send(src, job) end)
    AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) seen[src] = nil end)
    AddEventHandler('playerDropped', function() seen[source] = nil end)
end
