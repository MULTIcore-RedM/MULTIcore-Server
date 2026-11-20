-- ============================================================
-- MULTIgathering :: server exports (see README)
-- ============================================================

exports('IsReady', function() return MG.ready end)
exports('IsActive', function(activity) return MG.Active(activity) == true end)
exports('StandingDownFor', function(activity) return MG.StandingDownFor(activity) end)

-- mining / lumber / panning
exports('Start', function(src, activity, target) return MG.Start(src, activity, target) end)
exports('Finish', function(src) return MG.Finish(src) end)
exports('Cancel', function(src) return MG.Cancel(src) end)
exports('GetSpot', function(id)
    local s = MG.Spots[id]
    if not s then return nil end
    local st = MG.Spot(id)
    return { id = id, kind = s.kind, left = st.left, charges = s.def.charges, depleted = st.left <= 0 }
end)
exports('Roll', function(tbl) return MG.Roll(tbl) end)

-- fishing
exports('Cast', function(src, bait) return MG.Cast(src, bait) end)
exports('Catch', function(src, model, kg) return MG.Catch(src, model, kg) end)
exports('HasCast', function(src) return MG.HasCast(src) end)
exports('GetFish', function(model)
    local d = MG.FishDef(model)
    return d and { model = d.model, item = d.item, min = d.min, max = d.max } or nil
end)

-- herbs
exports('Pick', function(src, key) return MG.Pick(src, key) end)
exports('IsPicked', function(key) return MG.IsPicked(key) end)
exports('GetHerbSpot', function(key)
    local s = MG.HerbSpots[key]
    return s and { key = s.key, coords = s.coord, plant = s.plant, item = Config.HerbItems[s.plant] } or nil
end)
