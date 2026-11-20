-- ============================================================
-- MULTIcore :: character login API
-- Used by MULTIcharacter (select, create, delete) and MULTIcreator /
-- MULTItailor (looks). See docs/BASE_SET.md for the contract.
-- ============================================================

MULTI.Login = {}
local L = MULTI.Login

local function decode(v)
    if type(v) ~= 'string' then return v end
    local ok, out = pcall(json.decode, v)
    if ok then return out end
    return nil
end

local function license(src)
    return RSGCore.Functions.GetIdentifier(src, 'license')
end

-- ---------------------------------------------------------------
-- Looks (format 'multi')
-- ---------------------------------------------------------------

local function clampNum(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- body slider ids a look may carry (skin.body), from MULTIData.BodyFeatures (data/appearance.lua)
local BODY_IDS = {}
for _, f in ipairs(MULTIData.BodyFeatures or {}) do BODY_IDS[f.id] = true end

local function cleanSkin(s)
    if type(s) ~= 'table' then return nil end
    local out = {
        sex = s.sex == 'female' and 'female' or 'male',
        head = math.floor(clampNum(s.head, 1, 9999, 1)),
        bodyUpper = math.floor(clampNum(s.bodyUpper, 1, 9999, 1)),
        bodyLower = math.floor(clampNum(s.bodyLower, 1, 9999, 1)),
        eyes = math.floor(clampNum(s.eyes, 1, 9999, 1)),
        teeth = math.floor(clampNum(s.teeth, 1, 9999, 1)),
        hair = math.floor(clampNum(s.hair, 0, 9999, 0)),
        beard = math.floor(clampNum(s.beard, 0, 9999, 0)),
        bodyType = math.floor(clampNum(s.bodyType, 0, 99, 0)),
        waist = math.floor(clampNum(s.waist, 0, 99, 0)),
        height = clampNum(s.height, MULTIConfig.Look.MinHeight, MULTIConfig.Look.MaxHeight, 1.0),
        features = {},
        body = {},
        overlays = {},
    }
    -- keep any extra fields a creator adds (skin tone, hair colour ...), plain values only
    for k, v in pairs(s) do
        if out[k] == nil and (type(v) == 'number' or type(v) == 'string' or type(v) == 'boolean') and #tostring(k) <= 32 then
            out[k] = v
        end
    end
    if type(s.features) == 'table' then
        for k, v in pairs(s.features) do
            if type(k) == 'string' and k:match('^0x%x+$') then out.features[k] = clampNum(v, -1.0, 1.0, 0.0) end
        end
    end
    -- body sliders: { ['<MetaPedExpression id>'] = -1.0 .. 1.0 }, only ids from the fixed list (string keys keep the JSON an object)
    if type(s.body) == 'table' then
        for k, v in pairs(s.body) do
            local id = tonumber(k)
            if id and BODY_IDS[id] then out.body[tostring(math.floor(id))] = clampNum(v, -1.0, 1.0, 0.0) end
        end
    end
    if type(s.overlays) == 'table' then
        for name, o in pairs(s.overlays) do
            if type(name) == 'string' and #name <= 32 and type(o) == 'table' then
                out.overlays[name] = {
                    tx = math.floor(clampNum(o.tx, 1, 999, 1)),
                    var = math.floor(clampNum(o.var, 0, 99, 0)),
                    opacity = clampNum(o.opacity, 0.0, 1.0, 1.0),
                    palette = math.floor(clampNum(o.palette, 1, 25, 1)),
                    c1 = math.floor(clampNum(o.c1, 0, 254, 0)),
                    c2 = math.floor(clampNum(o.c2, 0, 254, 0)),
                    c3 = math.floor(clampNum(o.c3, 0, 254, 0)),
                    colorType = tonumber(o.colorType) and math.floor(clampNum(o.colorType, 0, 2, 0)) or nil, -- kept only when given
                }
            end
        end
    end
    return out
end

local function cleanComps(c)
    if type(c) ~= 'table' then return nil end
    local out = {}
    for cat, p in pairs(c) do
        if type(cat) == 'string' and #cat <= 40 and type(p) == 'table' and tonumber(p.index) then
            out[cat] = {
                index = math.floor(clampNum(p.index, 1, 99999, 1)),
                palette = tonumber(p.palette) and math.floor(tonumber(p.palette)) or nil,
                tint0 = tonumber(p.tint0) and math.floor(clampNum(p.tint0, 0, 254, 0)) or nil,
                tint1 = tonumber(p.tint1) and math.floor(clampNum(p.tint1, 0, 254, 0)) or nil,
                tint2 = tonumber(p.tint2) and math.floor(clampNum(p.tint2, 0, 254, 0)) or nil,
            }
        end
    end
    return out
end

L.CleanSkin, L.CleanComps = cleanSkin, cleanComps

function L.GetLook(citizenid)
    local e = MULTI.Appearance.Get(citizenid, 'multi')
    if not e.skin and not e.comps then return nil end
    return { skin = decode(e.skin) or {}, comps = decode(e.comps) or {} }
end

function L.SaveLookFor(citizenid, part, value)
    if part == 'both' then
        if type(value) ~= 'table' then return false end
        local s, c = cleanSkin(value.skin), cleanComps(value.comps)
        if not s or not c then return false end
        MULTI.Appearance.Set(citizenid, 'multi', 'skin', s)
        MULTI.Appearance.Set(citizenid, 'multi', 'comps', c)
        return true
    elseif part == 'skin' then
        local s = cleanSkin(value)
        return s and MULTI.Appearance.Set(citizenid, 'multi', 'skin', s) or false
    elseif part == 'comps' then
        local c = cleanComps(value)
        return c and MULTI.Appearance.Set(citizenid, 'multi', 'comps', c) or false
    end
    return false
end

function L.SaveLook(src, part, value)
    local P = RSGCore.Players[src]
    if not P then return false end
    local ok = L.SaveLookFor(P.PlayerData.citizenid, part, value)
    if ok then
        TriggerEvent('MULTIcore:lookChanged', src, part)
        -- the client keeps a cached copy (exports.MULTIcore:GetLook); hand it the saved look
        TriggerClientEvent('MULTIcore:client:lookChanged', src, L.GetLook(P.PlayerData.citizenid))
    end
    return ok
end

-- ---------------------------------------------------------------
-- Characters
-- ---------------------------------------------------------------

function L.GetCharacters(src)
    local lic = license(src)
    if not lic then return {} end
    MULTI.Schema.Wait()
    local rows = MySQL.query.await('SELECT id, citizenid, charinfo, job, money, position FROM players WHERE license = ? ORDER BY id', { lic }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ci, job, money = decode(r.charinfo) or {}, decode(r.job) or {}, decode(r.money) or {}
        out[#out + 1] = {
            citizenid = r.citizenid,
            id = r.id,
            firstname = ci.firstname,
            lastname = ci.lastname,
            gender = (ci.gender == 1 or ci.gender == '1') and 'female' or 'male',
            birthdate = ci.birthdate,
            nationality = ci.nationality,
            job = job.name,
            jobLabel = job.label,
            cash = money.cash or 0,
            bank = money.bank or 0,
            gold = money.gold or 0,
            lastPosition = decode(r.position),
            look = L.GetLook(r.citizenid),
        }
    end
    return out
end

local function slotsFor(src)
    local acc = MULTI.Accounts.Get(src)
    return (acc and acc.maxCharacters) or MULTIConfig.Vorp.MaxCharacters
end

local function cleanName(s)
    s = tostring(s or ''):gsub('[%c<>"\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s < 1 or #s > 30 then return nil end
    return s
end

function L.CreateCharacter(src, info, look)
    if RSGCore.Players[src] then return false, 'already_loaded' end
    local lic = license(src)
    if not lic or type(info) ~= 'table' then return false, 'bad_request' end
    local first, last = cleanName(info.firstname), cleanName(info.lastname)
    if not first or not last then return false, 'bad_name' end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { lic }) or 0
    if count >= slotsFor(src) then return false, 'no_slots' end
    local birth = tostring(info.birthdate or '')
    if not birth:match('^%d%d%d%d%-%d%d%-%d%d$') then birth = MULTIConfig.Look.DefaultBirthdate end
    local female = info.gender == 'female'
    local skin = look and cleanSkin(look.skin)
    if skin then skin.sex = female and 'female' or 'male' end

    MULTI.Accounts.Load(src)
    local ok = RSGCore.Player.Login(src, false, {
        license = lic,
        charinfo = {
            firstname = first,
            lastname = last,
            gender = female and 1 or 0,
            birthdate = birth,
            nationality = cleanName(info.nationality) or MULTIConfig.Look.DefaultNationality,
        },
    })
    local P = ok and RSGCore.Players[src]
    if not P then return false, 'login_failed' end
    -- VORP-only details go straight into the character's VORP fields
    local v = P.PlayerData.metadata.vorp
    if v then
        v.age = tonumber(info.age) or v.age
        v.nickname = info.nickname and tostring(info.nickname):sub(1, 40) or v.nickname
        v.description = info.description and tostring(info.description):sub(1, 500) or v.description
        P.Functions.SetMetaData('vorp', v)
    end
    if skin then MULTI.Appearance.Set(P.PlayerData.citizenid, 'multi', 'skin', skin) end
    local comps = look and cleanComps(look.comps)
    if comps then MULTI.Appearance.Set(P.PlayerData.citizenid, 'multi', 'comps', comps) end
    TriggerEvent('MULTIcore:characterSelected', src, P.PlayerData.citizenid, true)
    TriggerClientEvent('MULTIcore:client:characterSelected', src, true)
    return P.PlayerData.citizenid
end

function L.SelectCharacter(src, citizenid)
    if RSGCore.Players[src] then return false end
    local lic = license(src)
    if not lic or type(citizenid) ~= 'string' then return false end
    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    if owner ~= lic then return false end
    MULTI.Accounts.Load(src)
    if not RSGCore.Player.Login(src, citizenid) or not RSGCore.Players[src] then return false end
    TriggerEvent('MULTIcore:characterSelected', src, citizenid, false)
    TriggerClientEvent('MULTIcore:client:characterSelected', src, false)
    return true
end

function L.DeleteCharacter(src, citizenid)
    local lic = license(src)
    if not lic or type(citizenid) ~= 'string' then return false end
    local P = RSGCore.Players[src]
    if P and P.PlayerData.citizenid == citizenid then return false end -- can't delete the one in play
    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    if owner ~= lic then return false end
    RSGCore.Player.DeleteCharacter(src, citizenid)
    TriggerEvent('MULTIcore:characterDeleted', src, citizenid)  -- base scripts clean up their own tables
    return true
end

function L.LogoutCharacter(src)
    if not RSGCore.Players[src] then return false end
    RSGCore.Player.Logout(src)
    TriggerClientEvent('MULTIcore:client:loggedOut', src)
    return true
end

-- ---------------------------------------------------------------
-- Exports and client callbacks
-- ---------------------------------------------------------------

exports('GetCharacters', L.GetCharacters)
exports('GetAccountSlots', slotsFor)
exports('CreateCharacter', L.CreateCharacter)
exports('SelectCharacter', L.SelectCharacter)
exports('DeleteCharacter', L.DeleteCharacter)
exports('LogoutCharacter', L.LogoutCharacter)
exports('GetLook', L.GetLook)
exports('SaveLook', L.SaveLook)

lib.callback.register('MULTIcore:chars:list', function(src) return L.GetCharacters(src) end)
lib.callback.register('MULTIcore:chars:create', function(src, info, look) return L.CreateCharacter(src, info, look) end)
lib.callback.register('MULTIcore:chars:select', function(src, citizenid) return L.SelectCharacter(src, citizenid) end)
lib.callback.register('MULTIcore:chars:delete', function(src, citizenid) return L.DeleteCharacter(src, citizenid) end)
lib.callback.register('MULTIcore:look:get', function(src)
    local P = RSGCore.Players[src]
    return P and L.GetLook(P.PlayerData.citizenid) or nil
end)
lib.callback.register('MULTIcore:look:save', function(src, part, value) return L.SaveLook(src, part, value) end)
