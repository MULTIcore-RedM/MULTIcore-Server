--[[
    Sewing: the needlework minigame sessions (outfits and recipe batches) and the bench recipes.

    lib.callback:
      multitailor:sew:open   (pointId)                                     -> { recipes, pockets, itemLabels, maxBatch } | nil, err
      multitailor:sew:start  ({ pointId, kind = 'outfit'|'recipe' })       -> { ok, token, rounds, keys } | { ok = false, error }
      multitailor:sew:craft  ({ pointId, token, hits, recipe, amount })    -> { ok, error?, pockets? }
    A session belongs to one player and one point, lives Config.Sewing.sessionTtl seconds and can be
    used once. TL.checkSession refuses replies that come back faster than the rounds can be played.
]]
TSew = TSew or {}

local sessions = {}   -- [src] = { token, kind, pointId, rounds, startedAt, expiresAt }
local busy = {}

function TSew.start(src, pointId, kind)
    local now = GetGameTimer()
    local token = ('%d%06d'):format(now % 100000, math.random(0, 999999))
    sessions[src] = { token = token, kind = kind, pointId = pointId, rounds = #Config.Sewing.rounds,
                      startedAt = now, expiresAt = now + (Config.Sewing.sessionTtl or 120) * 1000 }
    return token
end

----> true, hits | false, error text. The session is spent either way.
function TSew.finish(src, token, hits, kind, pointId)
    local s = sessions[src]
    sessions[src] = nil
    if not s or s.token ~= tostring(token) or s.kind ~= kind or s.pointId ~= pointId then return false, L('err_sew_session') end
    local ok, n = TL.checkSession(s, GetGameTimer(), hits)
    if not ok then
        TU.debug('sewing session refused for %s: %s', tostring(src), tostring(n))
        return false, L('err_sew_session')
    end
    return true, n
end

local function recipeById(id)
    for _, r in ipairs(Config.Sewing.recipes or {}) do if r.id == id then return r end end
    return nil
end

local function point(src, pointId)
    local p, role = TP.access(src, pointId, 'staff')
    if not p then return nil, role end
    if p.kind ~= 'craft' then return nil, L('err_no_access') end
    return p
end

lib.callback.register('multitailor:sew:open', function(src, pointId)
    if not TA.rate(src, 'default') then return nil, L('err_slow') end
    local p, err = point(src, pointId)
    if not p then return nil, err end
    local list = {}
    for _, r in ipairs(Config.Sewing.recipes or {}) do
        local req = {}
        for _, m in ipairs(r.required or {}) do req[#req + 1] = { item = m.item, amount = m.amount } end
        list[#list + 1] = { id = r.id, label = r.label, receive = r.receive, amount = r.amount, required = req }
    end
    local b = TP.business(p)
    return { pointId = p.id, businessLabel = b and b.label or Config.Tailor.label, recipes = list,
             pockets = TDesigner.pockets(src), itemLabels = TDesigner.itemLabels(), maxBatch = Config.Sewing.maxBatch or 10 }
end)

lib.callback.register('multitailor:sew:start', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = point(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local kind = data.kind == 'recipe' and 'recipe' or 'outfit'
    return { ok = true, token = TSew.start(src, p.id, kind), rounds = Config.Sewing.rounds, keys = Config.Sewing.keys }
end)

lib.callback.register('multitailor:sew:craft', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'cut') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, err = point(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local r = recipeById(data.recipe)
    local amount = TU.int(data.amount, 1, Config.Sewing.maxBatch or 10)
    if not r or not amount then return { ok = false, error = L('err_bad_recipe') } end
    local okS, hits = TSew.finish(src, data.token, data.hits, 'recipe', p.id)
    if not okS then return { ok = false, error = hits } end
    busy[src] = true
    local result
    local ok, e = pcall(function()
        local short = {}
        for _, m in ipairs(r.required) do
            local need = m.amount * amount
            local have = TA.count(src, m.item)
            if have < need then short[#short + 1] = ('%d %s'):format(need - have, TA.label(m.item)) end
        end
        if #short > 0 then result = { ok = false, error = L('err_missing', table.concat(short, ', ')) } return end
        local out = r.amount * amount
        if hits == 0 then out = math.max(1, math.floor(out / 2)) end
        if not TA.canCarry(src, r.receive, out) then result = { ok = false, error = L('err_no_room') } return end
        local taken = {}
        for _, m in ipairs(r.required) do
            if not TA.remove(src, m.item, m.amount * amount) then
                for it, k in pairs(taken) do TA.give(src, it, k) end
                result = { ok = false, error = L('err_cut_failed') }
                return
            end
            taken[m.item] = (taken[m.item] or 0) + m.amount * amount
        end
        if not TA.give(src, r.receive, out) then
            for it, k in pairs(taken) do TA.give(src, it, k) end
            result = { ok = false, error = L('err_no_room') }
            return
        end
        TriggerEvent('MULTItailor:sewn', src, { recipe = r.id, item = r.receive, amount = out })
        TA.notify(src, hits == 0 and L('sew_ok_poor', out, TA.label(r.receive)) or L('sew_ok', out, TA.label(r.receive)), 'success')
        result = { ok = true, made = out, pockets = TDesigner.pockets(src) }
    end)
    busy[src] = nil
    if not ok then
        print(('^1[MULTItailor] sewing failed: %s^0'):format(tostring(e)))
        return { ok = false, error = L('err_cut_failed') }
    end
    return result
end)

AddEventHandler('playerDropped', function() sessions[source] = nil busy[source] = nil end)
