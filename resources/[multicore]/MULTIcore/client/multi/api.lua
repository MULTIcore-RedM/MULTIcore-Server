-- ============================================================
-- MULTIcore :: native API (client)
-- The local player's own character, for scripts made only for MULTIcore.
-- Full list and examples: docs/API.md
-- ============================================================

local MC = {}

local function copyRole(r)
    if type(r) ~= 'table' then return nil end
    local g = type(r.grade) == 'table' and r.grade or {}
    return {
        name = r.name, label = r.label,
        grade = tonumber(g.level) or 0, gradeLabel = g.name,
        isBoss = r.isboss == true or g.isboss == true,
        onDuty = r.onduty == true,
    }
end

--- True once the local player has a character loaded.
function MC.IsLoggedIn() return LocalPlayer.state.isLoggedIn == true end

--- A plain copy of the local character (same shape as the server's GetCharacter).
function MC.GetCharacter()
    local d = RSGCore.PlayerData
    if not MC.IsLoggedIn() or type(d) ~= 'table' or not d.citizenid then return nil end
    local ci, money = d.charinfo or {}, {}
    for k, v in pairs(d.money or {}) do money[k] = v end
    return {
        source = GetPlayerServerId(PlayerId()), citizenid = d.citizenid,
        firstname = ci.firstname, lastname = ci.lastname,
        name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        gender = ci.gender,
        job = copyRole(d.job), gang = copyRole(d.gang),
        money = money,
    }
end

function MC.GetJob() local c = MC.GetCharacter() return c and c.job or nil end
function MC.GetGang() local c = MC.GetCharacter() return c and c.gang or nil end
function MC.GetMoney(account) local c = MC.GetCharacter() return c and (c.money[account or 'cash'] or 0) or 0 end
function MC.GetMeta(key) local d = RSGCore.PlayerData return d and d.metadata and d.metadata[key] or nil end

--- Count of an item in the local player's inventory (display only: always check again on the server).
function MC.CountItem(name)
    if GetResourceState('MULTIinventory') ~= 'started' then return 0 end
    return exports.MULTIinventory:GetItemCount(name) or 0
end
function MC.HasItem(name, amount) return MC.CountItem(name) >= (tonumber(amount) or 1) end

function MC.GetApiVersion() return 1 end

MULTI.Api = MC
for name, fn in pairs(MC) do exports(name, fn) end
