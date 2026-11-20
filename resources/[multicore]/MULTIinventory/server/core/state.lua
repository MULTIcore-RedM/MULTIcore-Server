-- ============================================================
-- MULTIinventory :: server/core/state.lua
--
-- Character lifecycle + UI sessions.
--   load   : VORP vorp:SelectedCharacter / RSG RSGCore:Server:PlayerLoaded (via the bridge),
--            and every online player when the resource (re)starts
--   unload : playerDropped (flush + evict player/equip containers)
-- Sessions: which secondary container each player has open (one at a time),
-- single-viewer locks for non-shared containers (flags.shared = false).
--
--   State.get(src) -> { src, charId, capacity, name, identifier } | nil
--   State.srcOfChar(charId) -> src|nil
--   State.attach(src, charId, info) / State.detach(src)
--   State.capacityOf(charId) -> kg|nil      State.prefetchCapacity(charId)   (offline: may yield)
--   State.open(src, containerId|nil, opts) -> ok, err      opts.admin, opts.label
--   State.close(src, notifyClient)
--   State.viewersOf(containerId) -> { [src] = true }
--   State.secondaryOf(src) -> containerId|nil
--   State.canAccess(src, containerId) -> bool (own player/equip or the open secondary)
--   State.currency(src) -> { cash, gold }
-- Events (server-local): MULTIinventory:containerOpened (src, id), MULTIinventory:containerClosed (src, id)
-- ============================================================

State = State or {}

local bySrc, byChar = {}, {}
local viewers = {}     -- [containerId] = { [src] = true }
local sessions = {}    -- [src] = { secondary = id|nil, admin = bool, open = bool }
local locks = {}       -- [containerId] = src
local offlineCap = {}  -- [charId] = kg
local CAP_TTL = 5

local function fwChar(src)
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    if not ok or not user then return nil end
    local char = user.getUsedCharacter
    if type(char) == 'function' then char = char() end
    return char
end

local function readCapacity(char)
    if not Config.Player.useFrameworkCapacity or not char then return nil end
    return tonumber(char.invCapacity)
end

function State.get(src) return bySrc[tonumber(src)] end
function State.srcOfChar(charId) return byChar[tonumber(charId)] end
function State.all() return bySrc end

function State.capacityOf(charId)
    charId = tonumber(charId)
    local src = byChar[charId]
    if src then
        local st = bySrc[src]
        if st.capAt and Util.now() - st.capAt < CAP_TTL then return st.capacity end
        local cap = readCapacity(fwChar(src))
        if cap then st.capacity = cap end
        st.capAt = Util.now()
        return st.capacity
    end
    return offlineCap[charId]
end

---For offline characters: read the VORP capacity (characters.slots, read-only). Yields.
function State.prefetchCapacity(charId)
    charId = tonumber(charId)
    if not charId or byChar[charId] or offlineCap[charId] then return end
    if MBridge.IsVorp and Config.Player.useFrameworkCapacity then
        local v = InvDB.scalar('SELECT `slots` FROM `characters` WHERE `charidentifier` = ?', { charId })
        offlineCap[charId] = tonumber(v) or Config.Player.defaultMaxWeight
    else
        offlineCap[charId] = Config.Player.defaultMaxWeight
    end
end

function State.attach(src, charId, info)
    src, charId = tonumber(src), tonumber(charId)
    if not src or not charId then return false end
    local prev = bySrc[src]
    if prev and prev.charId ~= charId then State.detach(src) end
    info = info or {}
    bySrc[src] = { src = src, charId = charId, capacity = info.capacity or Config.Player.defaultMaxWeight,
                   capAt = info.capacity and Util.now() or nil, name = info.name, identifier = info.identifier }
    byChar[charId] = src
    offlineCap[charId] = nil
    Containers.get('player:' .. charId, { create = true })
    Containers.get('equip:' .. charId, { create = true })
    Hotbar.load(charId)
    InvHooks.emit('characterLoaded', src, charId)
    Sync.sendFull(src)
    return true
end

function State.detach(src)
    src = tonumber(src)
    local st = bySrc[src]
    if not st then return end
    State.close(src, false)
    InvHooks.emit('characterUnloaded', src, st.charId)
    bySrc[src] = nil
    if byChar[st.charId] == src then byChar[st.charId] = nil end
    Hotbar.unload(st.charId)
    Containers.unload('player:' .. st.charId)
    Containers.unload('equip:' .. st.charId)
end

function State.viewersOf(id) return viewers[id] or {} end
function State.secondaryOf(src) local s = sessions[src] return s and s.secondary end
function State.isOpen(src) local s = sessions[src] return s ~= nil and s.open == true end

function State.canAccess(src, id)
    local st = bySrc[src]
    if not st then return false end
    if id == 'player:' .. st.charId or id == 'equip:' .. st.charId then return true end
    local s = sessions[src]
    return s ~= nil and s.secondary == id
end

function State.isAdminSession(src)
    local s = sessions[src]
    return s ~= nil and s.admin == true
end

function State.currency(src)
    local ch = fwChar(src)
    return { cash = ch and tonumber(ch.money) or 0, gold = ch and tonumber(ch.gold) or 0 }
end

local function lockOk(src, c)
    if c.flags and c.flags.shared then return true end
    local holder = locks[c.id]
    if holder and holder ~= src and sessions[holder] and sessions[holder].secondary == c.id then
        return false
    end
    return true
end

function State.open(src, id, opts)
    opts = opts or {}
    local st = bySrc[src]
    if not st then return false, 'player_not_loaded' end
    local sec
    if id and id ~= 'player:' .. st.charId then
        sec = Containers.get(id)
        if not sec then return false, 'unknown_container' end
        if not opts.admin then
            local ok, err = InvHooks.check('canOpen', src, sec, opts)
            if not ok then return false, err end
        end
        if not lockOk(src, sec) then return false, 'locked' end
    end
    -- close any previous secondary first
    local s = sessions[src]
    if s and s.secondary and (not sec or s.secondary ~= sec.id) then
        local old = s.secondary
        if viewers[old] then viewers[old][src] = nil end
        if locks[old] == src then locks[old] = nil end
        TriggerEvent('MULTIinventory:containerClosed', src, old)
    end
    sessions[src] = { secondary = sec and sec.id or nil, admin = opts.admin == true, open = true }
    if sec then
        viewers[sec.id] = viewers[sec.id] or {}
        viewers[sec.id][src] = true
        if not (sec.flags and sec.flags.shared) then locks[sec.id] = src end
    end
    local p = Containers.get('player:' .. st.charId, { create = true })
    local e = Containers.get('equip:' .. st.charId, { create = true })
    local load, cap = Inv.weight(p)
    local payload = {
        player = Sync.containerView(p),
        equipment = Sync.containerView(e),
        secondary = sec and Sync.containerView(sec) or nil,
        secondaryLabel = opts.label,
        hotbar = Hotbar.view(st.charId),
        currency = State.currency(src),
        weight = { current = Util.round(load, 2), max = cap },
        groups = Registry.groups(),
        config = {
            slots = Config.Player.slots,
            hotbarSlots = Config.Player.hotbarSlots,
            dropMode = Config.Drop.mode,
            confirmDelete = Config.Drop.confirmDelete,
            imagePath = Config.Images.itemPath,
            imageFallback = Config.Images.fallback,
            showCurrency = Config.Player.showCurrency,
            wornCountsWeight = Config.Player.wornClothingCountsWeight,
        },
    }
    InvHooks.emit('openPayload', src, payload)
    TriggerClientEvent('MULTIinventory:cl:open', src, payload)
    TriggerEvent('MULTIinventory:containerOpened', src, sec and sec.id or ('player:' .. st.charId))
    return true
end

function State.close(src, notifyClient)
    local s = sessions[src]
    sessions[src] = nil
    if s and s.secondary then
        local id = s.secondary
        if viewers[id] then viewers[id][src] = nil; if next(viewers[id]) == nil then viewers[id] = nil end end
        if locks[id] == src then locks[id] = nil end
        TriggerEvent('MULTIinventory:containerClosed', src, id)
    end
    if notifyClient ~= false then TriggerClientEvent('MULTIinventory:cl:close', src) end
    TriggerEvent('MULTIinventory:uiClosed', src)
    return true
end

-- ------------------------------------------------------------
-- Framework wiring
-- ------------------------------------------------------------
local function attachFromChar(src, char)
    if not char then return end
    local cid = tonumber(char.charIdentifier)
    if not cid then return end
    State.attach(src, cid, {
        capacity = readCapacity(char),
        name = ((char.firstname or '') .. ' ' .. (char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        identifier = char.identifier,
    })
end
State._attachFromChar = attachFromChar

function State.wireFramework()
    MBridge.OnCharacterSelected(function(src, char)
        src = tonumber(src)
        CreateThread(function()
            InvDB.awaitReady()
            attachFromChar(src, char or fwChar(src))
        end)
    end)
    AddEventHandler('playerDropped', function()
        local src = source
        CreateThread(function() State.detach(src) end)
    end)
    -- Forced respawn (VORP): items are NOT cleared (Config.Death).
    AddEventHandler('vorp:PlayerForceRespawn', function(a)
        local src = tonumber(a) or source
        if not Config.Death.clearOnForceRespawn then return end
        local st = bySrc[src]
        if not st then return end
        local keep = Config.Death.keepItems or {}
        local ctx = { src = src, reason = 'death' }
        local ok, removed = Inv.clear('player:' .. st.charId, { keep = keep }, ctx)
        if ok then InvLog.write('death_clear', { actorSrc = src, from = 'player:' .. st.charId, targetCharId = st.charId, data = { removed = removed } }) end
        if Config.Death.clearEquipped then
            local ok2, removed2 = Inv.clear('equip:' .. st.charId, { keep = keep }, ctx)
            if ok2 then InvLog.write('death_clear', { actorSrc = src, from = 'equip:' .. st.charId, targetCharId = st.charId, data = { removed = removed2 } }) end
        end
    end)
end

---Resource (re)start with players online: attach everyone who already has a character.
function State.attachOnline()
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local ok, char = pcall(fwChar, src)
        if ok and char then attachFromChar(src, char) end
    end
end

-- tests only
function State._reset()
    bySrc, byChar, viewers, sessions, locks, offlineCap = {}, {}, {}, {}, {}, {}
end
