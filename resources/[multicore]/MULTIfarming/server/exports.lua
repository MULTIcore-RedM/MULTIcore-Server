-- ============================================================
-- MULTIfarming :: server exports (see README)
-- ============================================================

exports('IsReady', function() return FM.ready end)

--- Every crop of a character: list of { id, crop, x, y, z, stage, ripe, dead, water }
exports('GetPlants', function(citizenid)
    local out, now = {}, FM.Time()
    for _, p in pairs(FM.Plants) do
        if p.citizenid == citizenid then
            FM.Advance(p, now)
            out[#out + 1] = { id = p.id, crop = p.crop, x = p.x, y = p.y, z = p.z, stage = FM.Stage(p),
                              ripe = FM.IsRipe(p), dead = p.deadAt ~= nil, water = math.floor(p.water + 0.5) }
        end
    end
    return out
end)

--- How many crops the player's character has in the ground (0 when not logged in).
exports('CountPlants', function(src)
    local cid = FM.CitizenId(src)
    return cid and FM.CountOf(cid) or 0
end)

-- the work steps, for other scripts that drive farming themselves
exports('Begin', function(src, action, target) return FM.Begin(src, action, target) end)
exports('Finish', function(src, data) return FM.Finish(src, data) end)
exports('Cancel', function(src) return FM.Cancel(src) end)
