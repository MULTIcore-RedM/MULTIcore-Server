-- ============================================================
-- MULTIconsumables :: per-character state (server)
-- One table per logged-in player, loaded from the character's RSGCore metadata:
--   multi_drunk      drunk level (number)
--   multi_drunk_at   os.time() of the last save (for sobering while logged out)
--   multi_addiction  { [substance] = { level, last, rec, relief, uses } }  (times are os.time())
-- ============================================================

MC = {
    State = {},     -- [src] = { cid, drunk, add = { [substance] = data }, dirty }
    Busy = {},      -- [src] = GetGameTimer() until which no new use may start
    Pending = {},   -- [src] = { name, token, from, minMs, expires } (Config.Use.ApplyOnStart = false)
    Blackout = {},  -- [src] = { started = os.time(), wakeBy = os.time() }
}

local RSGCore = exports['rsg-core']:GetCoreObject()
MC.Core = RSGCore

function MC.Debug(fmt, ...)
    if Config.Debug then print(('^5[MULTIconsumables]^7 ' .. fmt):format(...)) end
end

function MC.Player(src)
    src = tonumber(src)
    return src and RSGCore.Functions.GetPlayer(src) or nil
end

--- Notification in the game look (MULTIcore's own notify).
function MC.Notify(src, key, kind, ...)
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, { text = text, type = kind or 'info' }) end)
end

local function round2(v) return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100 end
MC.Round2 = round2

local function readAddiction(saved)
    local out = {}
    if type(saved) ~= 'table' then return out end
    for name, d in pairs(saved) do
        if type(d) == 'table' and Config.Addiction.Substances[name] then
            out[name] = {
                level = tonumber(d.level) or 0,
                last = tonumber(d.last) or 0,
                rec = tonumber(d.rec),
                relief = tonumber(d.relief) or 0,
                uses = tonumber(d.uses) or 0,
            }
        end
    end
    return out
end

local function writeAddiction(add)
    local out = {}
    for name, d in pairs(add) do
        if d.level > 0 or d.uses > 0 then
            out[name] = { level = round2(d.level), last = d.last, rec = d.rec, relief = d.relief, uses = d.uses }
        end
    end
    return out
end

--- The player's state (loads it from the metadata the first time, or after a character change).
--- → state, Player   or nil
function MC.Get(src)
    src = tonumber(src)
    local P = MC.Player(src)
    if not P then return nil end
    local cid = P.PlayerData.citizenid
    local s = MC.State[src]
    if s and s.cid == cid then return s, P end

    local meta = P.PlayerData.metadata or {}
    local now = os.time()
    s = { cid = cid, drunk = tonumber(meta.multi_drunk) or 0, add = readAddiction(meta.multi_addiction), dirty = false }
    local at = tonumber(meta.multi_drunk_at)
    if Config.Drunk.OfflineDecay and at and s.drunk > 0 and now > at then
        s.drunk = math.max(0, s.drunk - Config.Drunk.DecayPerMinute * (now - at) / 60)
    end
    if s.drunk >= (Config.Drunk.Blackout.At or math.huge) then s.drunk = Config.Drunk.Blackout.WakeLevel end -- never log in passed out
    MC.State[src] = s
    MC.Blackout[src] = nil
    if MC.Addiction then MC.Addiction.Recover(src, s, now, true) end
    MC.Save(src)
    MC.Debug('loaded %s (%s): drunk %.2f', src, cid, s.drunk)
    MC.Push(src)
    return s, P
end

--- Writes the state into the character's metadata (saved with the character by MULTIcore).
function MC.Save(src)
    local s = MC.State[tonumber(src)]
    local P = MC.Player(src)
    if not s or not P or P.PlayerData.citizenid ~= s.cid then return false end
    P.Functions.SetMetaData({
        multi_drunk = round2(s.drunk),
        multi_drunk_at = os.time(),
        multi_addiction = writeAddiction(s.add),
    })
    s.dirty = false
    return true
end

--- Sends the drunk level and the withdrawal effects to the player's client.
function MC.Push(src)
    local s = MC.State[tonumber(src)]
    if not s then return end
    TriggerClientEvent('MULTIconsumables:client:drunk', src, round2(s.drunk))
    if MC.Addiction then TriggerClientEvent('MULTIconsumables:client:withdrawal', src, MC.Addiction.ClientFlags(s)) end
end

local function unload(src)
    src = tonumber(src)
    if not src then return end
    if MC.State[src] then MC.Save(src) end
    MC.State[src], MC.Busy[src], MC.Pending[src], MC.Blackout[src] = nil, nil, nil, nil
end
MC.Unload = unload

-- RSGCore's unload fires before the character is saved, so our values go into that save
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) unload(src) end)
AddEventHandler('RSGCore:Server:PlayerDropped', function(Player)   -- fires before MULTIcore saves a leaving player
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then unload(src) end
end)
AddEventHandler('playerDropped', function() unload(source) end)    -- clean-up if the above did not run
AddEventHandler('MULTIcore:characterSelected', function(src) MC.State[tonumber(src)] = nil; MC.Get(src) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(MC.State) do MC.Save(src) end
end)

-- the client asks for its values after loading (and after this resource restarts)
RegisterNetEvent('MULTIconsumables:server:sync', function()
    local src = source
    if MC.Get(src) then MC.Push(src) end
end)
