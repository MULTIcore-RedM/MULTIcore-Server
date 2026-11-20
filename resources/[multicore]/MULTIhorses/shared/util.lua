-- ============================================================
-- MULTIhorses :: shared helpers (client and server)
-- Lookups built once from the config, prices, labels, name rules.
-- ============================================================

MH = MH or {}

MH.Stables = {}                     -- [id] = stable (config stables; the server may add script stables)
for _, s in ipairs(Config.Stables) do MH.Stables[s.id] = s end

MH.HorseByModel = {}
for _, h in ipairs(Config.Horses) do MH.HorseByModel[h.model] = h end

MH.TackByKey = {}
for _, c in ipairs(Config.Tack.Categories or {}) do MH.TackByKey[c.key] = c end

MH.FeedByItem = {}
for _, f in ipairs(Config.Feed) do MH.FeedByItem[f.item] = f end

MH.SellShare = math.max(0, math.min(tonumber(Config.SellBack) or 0, 0.5)) -- never more than half

local function cents(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end
MH.Cents = cents

function MH.Money(n)
    return ('%s%.2f'):format(Config.CurrencySign, cents(n))
end

function MH.PriceOf(model)
    local h = MH.HorseByModel[model]
    return h and h.price or Config.UnlistedPrice
end

--- What a stable pays for a horse (rounded down to the cent).
function MH.SellPrice(model)
    return math.floor(MH.PriceOf(model) * MH.SellShare * 100 + 1e-6) / 100
end

--- Does this stable sell that horse?
function MH.SoldAt(def, stableId)
    if not def then return false end
    if not def.stables then return true end
    for _, id in ipairs(def.stables) do if id == stableId then return true end end
    return false
end

function MH.HorseLabel(model)
    local h = MH.HorseByModel[model]
    if not h then return _L('horse_unlisted') end
    return _L('horse_label', _L('breed_' .. h.breed), _L('coat_' .. h.coat))
end

function MH.StableLabel(id)
    local s = MH.Stables[id]
    if not s then return tostring(id) end
    return s.label and _L(s.label) or s.id
end

--- Fee to bring a horse from one stable to another.
function MH.TransferFee(fromId, toId)
    local a, b = MH.Stables[fromId], MH.Stables[toId]
    local fee = Config.Transfer.BaseFee
    if a and b and a.coords and b.coords then fee = fee + #(a.coords - b.coords) * Config.Transfer.PerMetre end
    return cents(fee)
end

function MH.TackItem(catKey, hash)
    local c = MH.TackByKey[catKey]
    if not c then return nil end
    for i, it in ipairs(c.items) do if it.hash == hash then return it, i end end
    return nil
end

--- Cleans a horse name: letters (any language), digits, spaces, - and '. nil when not allowed.
function MH.CleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[%c<>"\\{}%[%]`$]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8 and utf8.len(name) or #name
    if not len or len < Config.NameMinLength or len > Config.NameMaxLength then return nil end
    return name
end

--- tack JSON from the database -> { saddle = hash, blanket = hash }
function MH.DecodeTack(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    return (ok and type(t) == 'table') and t or {}
end
