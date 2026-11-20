-- ============================================================
-- MULTIinventory :: client/nui.lua
--
-- NUI bridge. The core (client/main.lua) owns the Lua -> NUI messages
-- open / delta / hotbar / close / notify. This file adds:
--
--   NUI -> Lua callbacks (each answers { ok, err?, data? }):
--     server actions, forwarded unchanged through InvClient.nuiAction:
--       move split merge sort use give nearby drop pickup hotbar                   (core)
--       equip unequip clothingCatalog outfitList outfitSave outfitWear
--       outfitDelete outfitPack
--       weaponEquip weaponUnequip weaponDraw weaponClean weaponUnload weaponRename
--       weaponInspect weaponLoadout ammoBelt
--       search
--       contextAction                     (metadata `context` buttons; not registered yet, CR to core)
--     local:
--       ready      -> { ok, data = setup }   (the page asks once on load)
--       close      -> InvClient.close()
--       saddlebag  -> opens the mounted horse's bags (see below)
--
--   Lua -> NUI messages added by the ui part:
--     { action = 'setup', data = setup }      on every open (categories, locale, flags, mounted)
--     { action = 'pad',   data = { button } } controller buttons while open:
--        up down left right accept cancel x y lb rb
--
-- Saddlebag button: calls InvClient.saddlebag() (client/secondary.lua: finds the mount, notifies on failure);
-- if that hook is missing, the compat event vorp_inventory:Server:SaddleOpen
-- (handled by RINGOstables) is sent with the mount's network id.
-- ============================================================

InvNUI = InvNUI or {}

local SERVER_ACTIONS = {
    'move', 'split', 'merge', 'sort', 'use', 'give', 'nearby', 'drop', 'pickup', 'hotbar',
    'equip', 'unequip', 'clothingCatalog', 'outfitList', 'outfitSave', 'outfitWear', 'outfitDelete', 'outfitPack',
    'weaponEquip', 'weaponUnequip', 'weaponDraw', 'weaponClean', 'weaponUnload', 'weaponRename',
    'weaponInspect', 'weaponLoadout', 'ammoBelt',
    'search',
    'contextAction',
    'cash',                                                                          -- money items (Config.Money)
}

local function clean(d)
    if type(d) ~= 'table' then return {} end
    return d
end

for _, name in ipairs(SERVER_ACTIONS) do
    RegisterNUICallback(name, function(d, cb)
        if not InvClient or not InvClient.nuiAction then
            cb({ ok = false, err = 'not_ready' })
            return
        end
        InvClient.nuiAction(name, clean(d), cb)
    end)
end

-- ------------------------------------------------------------
-- setup data (small, sent on every open)
-- ------------------------------------------------------------
local function mountNetId()
    local ped = PlayerPedId()
    local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped, Citizen.ResultAsInteger()) -- GET_MOUNT
    if mount and mount ~= 0 and DoesEntityExist(mount) and NetworkGetEntityIsNetworked(mount) then
        return NetworkGetNetworkIdFromEntity(mount)
    end
    return nil
end

local function setupData()
    local cats = {}
    for i, c in ipairs(ClothingCategories or {}) do
        cats[i] = { order = c.order, key = c.key, item = c.item, panel = c.panel, label = c.label }
    end
    local loc = {}
    local dict = GetLocaleDict and GetLocaleDict() or {}
    for k, v in pairs(dict) do
        if type(v) == 'string' then loc[k] = v end
    end
    return {
        categories = cats,
        outfitItem = ClothingOutfitItem,
        locale = loc,
        saddleButton = (Config.Compat and Config.Compat.saddleButton) and true or false,
        mounted = mountNetId() ~= nil,
        dropMode = Config.Drop and Config.Drop.mode or 'world',
        confirmDelete = not (Config.Drop and Config.Drop.confirmDelete == false),
        giveDistance = Config.Give and Config.Give.maxDistance or 3.0,
        hotbarSlots = Config.Player and Config.Player.hotbarSlots or 5,
        allowCrossGender = Config.Clothing and Config.Clothing.allowCrossGender or false,
        allowRename = Config.Weapons and Config.Weapons.allowRename == true or false,
        -- sidearm holsters row (right hip / left hip = off-hand) in the equipment pane
        dualWield = (WeaponDefs and WeaponDefs.dualWield and WeaponDefs.dualWield()) and true or false,
        -- third sidearm: an "Extra holster" tile (Config.Weapons.extraSidearm)
        extraSidearm = (WeaponDefs and WeaponDefs.extraOn and WeaponDefs.extraOn()) and true or false,
        maxOutfits = Config.Clothing and Config.Clothing.maxOutfits or 20,
    }
end
InvNUI.setupData = setupData

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true, data = setupData() })
end)

RegisterNUICallback('close', function(_, cb)
    if InvClient and InvClient.isOpen and InvClient.isOpen() then
        InvClient.close()
    else
        SetNuiFocus(false, false) -- page and Lua disagree (e.g. page reloaded): release focus
    end
    cb({ ok = true })
end)

RegisterNUICallback('saddlebag', function(_, cb)
    -- client/secondary.lua owns the mount lookup (incl. last mount nearby) and the event
    if InvClient and type(InvClient.saddlebag) == 'function' then
        local ok = InvClient.saddlebag()
        cb({ ok = ok ~= false, err = ok == false and 'no_mount' or nil })
        return
    end
    local netId = mountNetId()
    if not netId then cb({ ok = false, err = 'no_mount' }) return end
    TriggerServerEvent('vorp_inventory:Server:SaddleOpen', netId)
    cb({ ok = true })
end)

AddEventHandler('MULTIinventory:client:opened', function()
    SendNUIMessage({ action = 'setup', data = setupData() })
end)

-- ------------------------------------------------------------
-- controller: forward frontend buttons to the page while open.
-- Keyboard and mouse reach the page directly through NUI focus.
-- Control hashes are joaat(input name) (checked: INPUT_FRONTEND_ACCEPT = 0xC7B5340A).
-- ------------------------------------------------------------
local PAD = {
    up = 'INPUT_FRONTEND_UP', down = 'INPUT_FRONTEND_DOWN',
    left = 'INPUT_FRONTEND_LEFT', right = 'INPUT_FRONTEND_RIGHT',
    accept = 'INPUT_FRONTEND_ACCEPT', cancel = 'INPUT_FRONTEND_CANCEL',
    x = 'INPUT_FRONTEND_X', y = 'INPUT_FRONTEND_Y',
    lb = 'INPUT_FRONTEND_LB', rb = 'INPUT_FRONTEND_RB',
}

CreateThread(function()
    local hashes = {}
    for btn, name in pairs(PAD) do hashes[btn] = joaat(name) end
    while true do
        if InvClient and InvClient.isOpen and InvClient.isOpen() then
            DisableAllControlActions(0)
            for btn, h in pairs(hashes) do
                if IsDisabledControlJustPressed(0, h) then
                    SendNUIMessage({ action = 'pad', data = { button = btn } })
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
