-- ============================================================
-- MULTIinventory :: client/hotbar.lua
--
-- Press the hotbar number (default 1..Config.Player.hotbarSlots) -> server action
-- hotbar { op = 'use', n }. The server resolves the slot against the player's own inventory:
-- items go through the same Usables.use path as the inventory Use button, weapons go to the
-- weapons part (draw; already in hand -> holster). Server-authoritative and rate limited.
--
-- Input, two ways (both deduplicated per slot):
--   1. RegisterKeyMapping '+multiinv_hotbarN' (rebindable: Settings > Key Bindings > FiveM/RedM).
--   2. Fallback: the game's quick-select controls (Config.Player.hotbarKeys), read with the
--      disabled variants too (the game disables them in many contexts). Turns itself off once a
--      key mapping has fired, so a rebound player is not double-triggered by the old number.
-- While a hotbar slot holds something its native quick-select is blocked (hotbarSuppressNative),
-- so the game does not swap weapons at the same time; empty slots keep the game behaviour.
--
-- Never fires while the inventory / any NUI has focus (chat typing), in the pause menu, while dead,
-- cuffed or hogtied.
--
-- Data model: InvClient.hotbar (pushed by the server: MULTIinventory:cl:sync / :cl:hotbar).
-- Assign/clear from the UI: InvClient.request('hotbar', { op = 'assign', n, slot }).
--
-- Key conflicts: 1-5 are the game's weapon quick-select keys (see above). PageDown opens vorp_admin
-- on this server and is not used here.
-- ============================================================

local P = Config.Player or {}
local SLOTS = math.max(0, math.min(tonumber(P.hotbarSlots) or 5, 9))

local busy = false
local lastFire = {}          -- [n] = GetGameTimer() of the last accepted press
local mappingSeen = false    -- a key mapping fired: the control fallback is not needed
local DEDUPE_MS = 400

local function yesNative(v) return v == true or v == 1 end

local function restrained(ped)
    local ok, res = pcall(function()
        return yesNative(Citizen.InvokeNative(0x74E559B3BC910685, ped))      -- IS_PED_CUFFED
            or yesNative(Citizen.InvokeNative(0x3AA24CCC0D451379, ped))      -- IS_PED_HOGTIED
    end)
    return ok and res == true
end

local function deadState(ped)
    if IsEntityDead(ped) then return true end
    local ok, res = pcall(function()
        if yesNative(IsPedDeadOrDying(ped, true)) then return true end
        local s = LocalPlayer and LocalPlayer.state
        return s ~= nil and (s.isDead == true or s.IsDead == true)
    end)
    return ok and res == true
end

local function assigned(n)
    for _, h in ipairs(InvClient.hotbar or {}) do
        if tonumber(h.slot) == n then return h end
    end
    return nil
end

local holdHash = InvClient.keyHash(P.hotbarHoldKey)

local function holdOk()
    if not holdHash then return true end
    return IsControlPressed(0, holdHash) or IsDisabledControlPressed(0, holdHash)
end

---Everything that blocks a hotbar press on this client (the server re-checks ownership and slot).
local function canUse()
    if InvClient.isOpen() then return false end              -- open UI: 1-5 assign while hovering
    if InvClient.sessionBlocked() then return false end      -- D&D character: its own 6-slot hotbar owns 1-6
    if IsNuiFocused and IsNuiFocused() then return false end -- chat / any NUI with focus
    if IsPauseMenuActive() then return false end
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.IsInvActive then return false end
    local ped = PlayerPedId()
    if deadState(ped) or restrained(ped) then return false end
    return holdOk()
end

local function useSlot(n)
    if busy then return end
    busy = true
    CreateThread(function()
        InvClient.request('hotbar', { op = 'use', n = n })
        busy = false
    end)
end

local function press(n)
    n = math.tointeger(tonumber(n))
    if not n or n < 1 or n > SLOTS then return end
    if not assigned(n) then return end                       -- empty slot: leave the key to the game
    local now = GetGameTimer()
    if lastFire[n] and now - lastFire[n] >= 0 and now - lastFire[n] < DEDUPE_MS then return end
    if not canUse() then return end
    lastFire[n] = now
    useSlot(n)
end
InvClient.hotbarPress = press

-- 1. key mappings ------------------------------------------------------------
local defaults = P.hotbarBindDefaults or {}
for n = 1, SLOTS do
    local cmd = 'multiinv_hotbar' .. n
    RegisterCommand('+' .. cmd, function()
        mappingSeen = true
        press(n)
    end, false)
    RegisterCommand('-' .. cmd, function() end, false)
    if RegisterKeyMapping then
        local key = defaults[n]
        if key == nil then key = tostring(n) end
        pcall(RegisterKeyMapping, '+' .. cmd, ('MULTIinventory hotbar slot %d'):format(n), 'keyboard', tostring(key))
    end
end

-- 2. control fallback + native quick-select suppression -------------------------
CreateThread(function()
    local keys = {}
    for i, k in ipairs(P.hotbarKeys or {}) do keys[i] = InvClient.keyHash(k) end
    local count = math.min(#keys, SLOTS)
    local suppress = P.hotbarSuppressNative ~= false
    while true do
        local any = false
        if count > 0 and not InvClient.isOpen() and not InvClient.sessionBlocked() then
            for n = 1, count do
                if assigned(n) then
                    any = true
                    local k = keys[n]
                    if suppress then DisableControlAction(0, k, true) end
                    if P.hotbarControlFallback ~= false and not mappingSeen
                        and (IsControlJustPressed(0, k) or IsDisabledControlJustPressed(0, k)) then
                        -- give a key mapping for the same press a moment to arrive first (dedupe)
                        CreateThread(function()
                            Wait(150)
                            if not mappingSeen then press(n) end
                        end)
                    end
                end
            end
        end
        Wait(any and 0 or 250)
    end
end)
