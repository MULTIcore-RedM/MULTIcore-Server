-- ============================================================
-- MULTIvoice :: server
-- Radio and call channels (who is on which), and the pma-voice server
-- exports other scripts call. Proximity voice itself runs on each player.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local channels = { radio = {}, call = {} }   -- [kind][channel] = { [src] = talking (bool) }
local current = { radio = {}, call = {} }    -- [kind][src] = channel
local checks = {}                            -- [radio channel] = function(src) -> bool

local function members(kind, ch)
    local list = {}
    for id in pairs(channels[kind][ch] or {}) do list[#list + 1] = id end
    return list
end

local function sendMembers(kind, ch)
    local list = members(kind, ch)
    for _, id in ipairs(list) do
        TriggerClientEvent('MULTIvoice:members', id, kind, ch, list)
    end
end

local function leave(kind, src)
    local ch = current[kind][src]
    if not ch then return end
    current[kind][src] = nil
    local set = channels[kind][ch]
    if set then
        set[src] = nil
        if next(set) == nil then channels[kind][ch] = nil else sendMembers(kind, ch) end
    end
    TriggerClientEvent('MULTIvoice:members', src, kind, 0, {})
    Player(src).state:set(kind .. 'Channel', 0, true)
end

--- Puts src on a channel (0 or nil = off it). Returns false when a channel check says no.
local function join(kind, src, ch)
    src = tonumber(src)
    ch = tonumber(ch) or 0
    if not src or src <= 0 then return false end
    if kind == 'radio' and not Config.Radio.Enabled then return false end
    if kind == 'call' and not Config.Call.Enabled then return false end
    leave(kind, src)
    if ch <= 0 then return true end
    if kind == 'radio' and checks[ch] then
        local ok, allowed = pcall(checks[ch], src)
        if not ok or not allowed then return false end
    end
    channels[kind][ch] = channels[kind][ch] or {}
    channels[kind][ch][src] = false
    current[kind][src] = ch
    Player(src).state:set(kind .. 'Channel', ch, true)
    sendMembers(kind, ch)
    return true
end

-- a player's own radio / call setting (client exports)
RegisterNetEvent('MULTIvoice:join', function(kind, ch)
    if kind ~= 'radio' and kind ~= 'call' then return end
    join(kind, source, ch)
end)

-- radio push-to-talk: tell the others on the channel who is talking
RegisterNetEvent('MULTIvoice:radioTalk', function(talking)
    local src = source
    local ch = current.radio[src]
    local set = ch and channels.radio[ch]
    if not set then return end
    set[src] = talking == true
    for id in pairs(set) do
        if id ~= src then TriggerClientEvent('MULTIvoice:radioTalking', id, src, talking == true) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    leave('radio', src)
    leave('call', src)
end)

-- ---------------------------------------------------------------
-- exports (also answered as exports['pma-voice'])
-- ---------------------------------------------------------------

local API = {}

function API.setPlayerRadio(src, ch) return join('radio', src, ch) end
function API.setPlayerCall(src, ch) return join('call', src, ch) end

--- { [src] = talking } for everyone on that radio channel.
function API.getPlayersInRadioChannel(ch)
    local out = {}
    for id, talking in pairs(channels.radio[tonumber(ch) or 0] or {}) do out[id] = talking end
    return out
end

--- Only players for whom fn(src) returns true may join that radio channel.
function API.addChannelCheck(ch, fn)
    ch = tonumber(ch)
    -- a function from another resource arrives as a callable table
    if ch and (type(fn) == 'function' or type(fn) == 'table') then checks[ch] = fn end
end

function API.removeChannelCheck(ch) checks[tonumber(ch) or 0] = nil end

-- pma-voice calls with nothing to do here (kept so scripts do not error)
function API.updateRoutingBucket() end
function API.setPlayerDefaultRange() end

for name, fn in pairs(API) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_pma-voice_%s'):format(name), function(setCB) setCB(fn) end)
end
