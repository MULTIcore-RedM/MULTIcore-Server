-- ============================================================
-- MULTIemotes :: catalogue (client and server)
-- Indexes config/emotes.lua and config/walkstyles.lua by id and
-- finds an emote / walk style by id or by its label in any
-- shipped language.
-- GPL v3.
-- ============================================================

MEM = MEM or {}
MEM.EmoteById, MEM.WalkById = {}, {}

for i, e in ipairs(Config.Emotes) do
    e.kind = e.emote and 'emote' or e.scenario and 'scenario' or (e.dict and e.clip) and 'anim' or nil
    e.order = i
    MEM.EmoteById[e.id] = e
end
for i, w in ipairs(Config.Walkstyles) do
    w.order = i
    MEM.WalkById[w.id] = w
end

local function norm(s)
    return tostring(s or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
end
MEM.Norm = norm

--- Looks `text` up by id first, then by label (the chosen language, then every language).
--- `prefix` is 'emote_' or 'walk_'; `byId` the index to search.
local function find(text, prefix, byId)
    local t = norm(text)
    if t == '' then return nil end
    if byId[t] then return byId[t] end
    for id, entry in pairs(byId) do
        if norm(_L(prefix .. id)) == t then return entry end
    end
    for _, lang in pairs(Locales) do
        for id, entry in pairs(byId) do
            if lang[prefix .. id] and norm(lang[prefix .. id]) == t then return entry end
        end
    end
    return nil
end

function MEM.FindEmote(text) return find(text, 'emote_', MEM.EmoteById) end
function MEM.FindWalk(text) return find(text, 'walk_', MEM.WalkById) end
