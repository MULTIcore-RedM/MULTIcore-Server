-- ============================================================
-- MULTIinventory :: client/main.lua
--
-- Client state cache + server request/response + NUI message contract hooks.
-- The UI (client/nui.lua, html/) builds on InvClient:
--
--   InvClient.request(action, data) -> ok, errOrResult   (yields; 10 s timeout)
--   InvClient.nuiAction(action, data, cb)                 cb({ ok, err, data }) - use in RegisterNUICallback
--   InvClient.open() / InvClient.close()
--   InvClient.isOpen()
--   InvClient.containers[id] = { id, kind, label, slots, weight, maxWeight, items = { [slot] = view } }
--   InvClient.playerId / equipId / secondaryId / hotbar / charId
--   InvClient.getItems() -> array of the player grid views (client exports / compat)
--
-- Lua -> NUI messages (SendNUIMessage):
--   { action = 'open',   data = { player, equipment, secondary?, hotbar, currency, weight, groups, config } }
--   { action = 'delta',  data = { container, kind, slots = { { slot, item|false } }, weight, maxWeight } }
--   { action = 'hotbar', data = { { slot, kind, ref, item, label, count } } }
--   { action = 'close' }   { action = 'notify', data = { text, type } }
-- NUI -> Lua callbacks:
--   move, split, merge, use, give, nearby, drop, pickup, hotbar, sort, close (+ part actions)
--
-- Also: open key, close on death, state bag IsInvActive, compat close event vorp_inventory:CloseInv.
-- ============================================================

InvClient = InvClient or {}
InvClient.containers = {}
InvClient.hotbar = {}

local pending, reqId = {}, 0
local opened = false

local function keyHash(k)
    if type(k) == 'number' then return k end
    if type(k) == 'string' then return joaat(k) end
    return nil
end
InvClient.keyHash = keyHash

local function storeView(view)
    if not view then return end
    local items = {}
    for _, it in ipairs(view.items or {}) do items[it.slot] = it end
    InvClient.containers[view.id] = { id = view.id, kind = view.kind, label = view.label, slots = view.slots,
                                      weight = view.weight, maxWeight = view.maxWeight, items = items }
end

function InvClient.request(action, data)
    reqId = reqId + 1
    local id = reqId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('MULTIinventory:sv:action', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ false, 'timeout' }) end
    end)
    local res = Citizen.Await(p)
    return res[1], res[2]
end

function InvClient.nuiAction(action, data, cb)
    CreateThread(function()
        local ok, res = InvClient.request(action, data)
        if ok then cb({ ok = true, data = res }) else cb({ ok = false, err = res }) end
    end)
end

RegisterNetEvent('MULTIinventory:cl:result', function(id, ok, res)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve({ ok, res }) end
end)

RegisterNetEvent('MULTIinventory:cl:sync', function(data)
    InvClient.charId = data.charId
    if data.player then InvClient.playerId = data.player.id; storeView(data.player) end
    if data.equipment then InvClient.equipId = data.equipment.id; storeView(data.equipment) end
    InvClient.hotbar = data.hotbar or {}
    TriggerEvent('MULTIinventory:client:synced')
end)

local function setActive(v)
    opened = v
    LocalPlayer.state:set('IsInvActive', v, true)
    -- rsg scripts read inv_busy (rsg-inventory sets it while its page is open)
    LocalPlayer.state:set('inv_busy', v, true)
end

RegisterNetEvent('MULTIinventory:cl:open', function(payload)
    storeView(payload.player)
    storeView(payload.equipment)
    InvClient.playerId = payload.player and payload.player.id
    InvClient.equipId = payload.equipment and payload.equipment.id
    InvClient.secondaryId = payload.secondary and payload.secondary.id or nil
    if payload.secondary then storeView(payload.secondary) end
    InvClient.hotbar = payload.hotbar or {}
    SendNUIMessage({ action = 'open', data = payload })
    SetNuiFocus(true, true)
    setActive(true)
    TriggerEvent('MULTIinventory:client:opened', payload)
end)

RegisterNetEvent('MULTIinventory:cl:delta', function(msg)
    local c = InvClient.containers[msg.container]
    if c then
        for _, s in ipairs(msg.slots or {}) do
            c.items[s.slot] = s.item or nil
        end
        c.weight, c.maxWeight = msg.weight, msg.maxWeight
    end
    if opened then SendNUIMessage({ action = 'delta', data = msg }) end
    TriggerEvent('MULTIinventory:client:delta', msg)
end)

RegisterNetEvent('MULTIinventory:cl:hotbar', function(list)
    InvClient.hotbar = list or {}
    SendNUIMessage({ action = 'hotbar', data = InvClient.hotbar })
end)

RegisterNetEvent('MULTIinventory:cl:notify', function(n)
    SendNUIMessage({ action = 'notify', data = n })
    TriggerEvent('MULTIinventory:client:notify', n)
end)

function InvClient.close(fromServer)
    if InvClient.secondaryId then InvClient.containers[InvClient.secondaryId] = nil end
    InvClient.secondaryId = nil
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    local was = opened
    setActive(false)
    if was and not fromServer then TriggerServerEvent('MULTIinventory:sv:action', 0, 'close', {}) end
    TriggerEvent('MULTIinventory:client:closed')
end

---True while another script holds the inventory shut: inv_busy (rsg scripts set it during
---their own actions) or an optional tabletop session (RINGOdnd) with its own bag and hotbar.
function InvClient.sessionBlocked()
    if LocalPlayer.state.inv_busy then return true end
    if GetResourceState('RINGOdnd') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.RINGOdnd:IsInDnd() end)
    return ok and res == true
end

function InvClient.open()
    if opened or InvClient.sessionBlocked() then return end
    CreateThread(function() InvClient.request('open', {}) end)
end

function InvClient.isOpen() return opened end

function InvClient.getItems()
    local out = {}
    local c = InvClient.playerId and InvClient.containers[InvClient.playerId]
    if c then for _, it in pairs(c.items) do out[#out + 1] = it end end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

RegisterNetEvent('MULTIinventory:cl:close', function() InvClient.close(true) end)
-- compat: vorp_core (spawn) and other resources close the inventory with this event
RegisterNetEvent('vorp_inventory:CloseInv', function() if opened then InvClient.close() end end)
AddEventHandler('MULTIinventory:close', function() if opened then InvClient.close() end end)

-- Near or on a horse the game's horse input context (mount / horse interaction prompts) marks the
-- open key (INPUT_QUICK_USE_ITEM) DISABLED, so IsControlJustReleased never fires there. Next to a
-- mount we also take the disabled release, unless the player is cuffed / hogtied (scripts disable the
-- key on purpose then). Opening is server-checked anyway (player loaded, rate limit).
local function finite(n) return type(n) == 'number' and n == n and n > -math.huge and n < math.huge end

local function horseRadius()
    local r = tonumber(Config.Player.horseOpenRadius)
    if not finite(r) or r < 0 then r = 6.0 end
    return math.min(r, 25.0)
end

local function yesNative(v) return v == true or v == 1 end

local function nearMount(ped)
    local ok, res = pcall(function()
        local m = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped, Citizen.ResultAsInteger()) -- GET_MOUNT
        if m and m ~= 0 and DoesEntityExist(m) then return true end
        local last = Citizen.InvokeNative(0x4C8B59171957BCF7, ped, Citizen.ResultAsInteger()) -- GET_LAST_MOUNT
        if last and last ~= 0 and DoesEntityExist(last) then
            local d = #(GetEntityCoords(last) - GetEntityCoords(ped))
            return finite(d) and d <= horseRadius()
        end
        return false
    end)
    return ok and res == true
end

local function restrained(ped)
    local ok, res = pcall(function()
        return yesNative(Citizen.InvokeNative(0x74E559B3BC910685, ped))      -- IS_PED_CUFFED
            or yesNative(Citizen.InvokeNative(0x3AA24CCC0D451379, ped))      -- IS_PED_HOGTIED
    end)
    return ok and res == true
end

local function openKeyReleased(key)
    if IsControlJustReleased(0, key) then return true end
    if not IsDisabledControlJustReleased(0, key) then return false end
    local ped = PlayerPedId()
    return nearMount(ped) and not restrained(ped)
end
InvClient._openKeyReleased = openKeyReleased

-- open key + close on death
CreateThread(function()
    local openKey = keyHash(Config.Player.openKey)
    while true do
        Wait(0)
        if openKey and not opened and openKeyReleased(openKey) then
            if not IsEntityDead(PlayerPedId()) and not IsPauseMenuActive() then InvClient.open() end
        end
        if opened and IsEntityDead(PlayerPedId()) then InvClient.close() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and opened then
        SetNuiFocus(false, false)
        LocalPlayer.state:set('IsInvActive', false, true)
        LocalPlayer.state:set('inv_busy', false, true)
    end
end)
