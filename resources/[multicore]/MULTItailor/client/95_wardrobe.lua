--[[
    Wardrobe (client): quick toggles, saved outfits, wardrobe points and rsg-wardrobe's client API.

    Toggles take a worn piece off for the moment: the item stays in its equipment slot, the piece is
    taken off the ped (MULTIcore RemoveComp, the body underneath comes back) and MULTIinventory is told
    it is hidden (it then leaves it off when it re-applies the worn set). Putting it back = shown again +
    exports.MULTIinventory:ReapplyClothing(). Nothing is saved; a new character select starts dressed.

    rsg-wardrobe client API (MULTItailor answers as rsg-wardrobe; names and arguments as RSG v2's):
      exports['rsg-wardrobe']:ToggleClothing(name)    name = 'hat', 'glove', 'shirt', 'coats' ... (TLook.WardrobeNames)
      exports['rsg-wardrobe']:RemoveAllClothing()     exports['rsg-wardrobe']:IsWearing(name) -> bool
      exports['rsg-wardrobe']:DressPlayer()           exports['rsg-wardrobe']:RemovePlayerClothing()
      net events  rsg-wardrobe:client:OnOffClothing (name), rsg-wardrobe:client:removeAllClothing,
                  MULTItailor:client:dress
    Outfit list: event MULTItailor:client:openOutfits (local or from the server), /outfits (Config.Outfits.command).
    Toggle menu: /clothes (Config.Toggles.command).
]]
local INV = 'MULTIinventory'
local hidden = {}          -- [slot key] = true while toggled off

local function invUp() return GetResourceState(INV) == 'started' end

local function worn()
    if not invUp() then return {} end
    local ok, w = pcall(function() return exports[INV]:GetWornLocal() end)
    return (ok and type(w) == 'table') and w or {}
end

local function busy()
    local ped = PlayerPedId()
    return TC.view ~= nil or IsEntityDead(ped)
end

-- ---------------------------------------------------------------- toggles
local function hideKeys(keys, w)
    local ped = PlayerPedId()
    for _, key in ipairs(keys) do
        if w[key] and not hidden[key] then
            hidden[key] = true
            TriggerEvent('vorp_character:Client:OnClothingRemoved', key)   -- MULTIinventory: hidden, still owned
            local slot = TLook.byKey[key]
            if slot and GetResourceState('MULTIcore') == 'started' then
                pcall(function() exports.MULTIcore:RemoveComp(ped, slot.game) end)
            else
                Citizen.InvokeNative(0xD710A5007C2AC539, ped, joaat(slot and slot.game or key), 0)
                TCN.updateVariation(ped)
            end
        end
    end
end

local function showKeys(keys)
    local any = false
    for _, key in ipairs(keys) do
        if hidden[key] then
            hidden[key] = nil
            TriggerEvent('vorp_character:Client:OnClothingAdded', key)
            any = true
        end
    end
    if any and invUp() then pcall(function() exports[INV]:ReapplyClothing() end) end
end

local function anyHidden(keys)
    for _, key in ipairs(keys) do if hidden[key] then return true end end
    return false
end

local function anyWorn(keys, w)
    for _, key in ipairs(keys) do if w[key] then return true end end
    return false
end

local function toggleClothing(name)
    local keys = TLook.keysFor(name)
    if #keys == 0 then return end
    if anyHidden(keys) then showKeys(keys) else hideKeys(keys, worn()) end
end

local function removeAllClothing()
    local w = worn()
    local keys = {}
    for key in pairs(w) do keys[#keys + 1] = key end
    hideKeys(keys, w)
end

local function dressPlayer()
    local keys = {}
    for key in pairs(hidden) do keys[#keys + 1] = key end
    showKeys(keys)
    if #keys == 0 and invUp() then pcall(function() exports[INV]:ReapplyClothing() end) end
end

local function isWearing(name)
    local w = worn()
    for _, key in ipairs(TLook.keysFor(name)) do
        if w[key] and not hidden[key] then return true end
    end
    return false
end

-- toggled-off pieces stay off when the look is put back on (respawn, reload)
AddEventHandler('MULTIinventory:client:clothingApplied', function(reason)
    if reason == 'preview' or not next(hidden) then return end
    local ped = PlayerPedId()
    local core = GetResourceState('MULTIcore') == 'started'
    for key in pairs(hidden) do
        local slot = TLook.byKey[key]
        if slot and core then
            pcall(function() exports.MULTIcore:RemoveComp(ped, slot.game) end)
        elseif slot then
            Citizen.InvokeNative(0xD710A5007C2AC539, ped, joaat(slot.game), 0)
        end
    end
    if not core then TCN.updateVariation(ped) end
end)

-- a new character starts dressed
RegisterNetEvent('MULTIcore:client:characterSelected', function() hidden = {} end)

local function wardrobeExport(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_rsg-wardrobe_%s'):format(name), function(setCB) setCB(fn) end)
end
wardrobeExport('ToggleClothing', toggleClothing)
wardrobeExport('RemoveAllClothing', removeAllClothing)
wardrobeExport('IsWearing', isWearing)
wardrobeExport('DressPlayer', dressPlayer)
wardrobeExport('RemovePlayerClothing', removeAllClothing)

RegisterNetEvent('rsg-wardrobe:client:OnOffClothing', toggleClothing)
RegisterNetEvent('rsg-wardrobe:client:removeAllClothing', removeAllClothing)
RegisterNetEvent('MULTItailor:client:dress', dressPlayer)

local function toggleMenu()
    if busy() then return TC.notify(L('err_busy'), 'error') end
    local w = worn()
    local options = {}
    for _, t in ipairs((Config.Toggles or {}).items or {}) do
        local owned, off = anyWorn(t.keys, w), anyHidden(t.keys)
        options[#options + 1] = {
            title = L('toggle_' .. t.id), icon = t.icon,
            description = (not owned and L('toggle_none')) or (off and L('toggle_off')) or L('toggle_on'),
            disabled = not owned,
            onSelect = function()
                if off then showKeys(t.keys) else hideKeys(t.keys, worn()) end
                Wait(150)
                toggleMenu()
            end,
        }
    end
    options[#options + 1] = {
        title = L('toggle_all'), icon = 'rotate-left', disabled = not next(hidden),
        onSelect = function() dressPlayer() Wait(150) toggleMenu() end,
    }
    lib.registerContext({ id = 'multitailor_toggles', title = L('toggles_title'), options = options })
    lib.showContext('multitailor_toggles')
end

local tg = Config.Toggles or {}
if tg.enabled ~= false and type(tg.command) == 'string' and tg.command ~= '' then
    RegisterCommand(tg.command, function() toggleMenu() end, false)
end

-- ---------------------------------------------------------------- saved outfits
local ERR = {
    too_far = 'outfit_too_far', bad_name = 'err_bad_name', outfit_limit = 'outfit_full', nothing_worn = 'outfit_nothing_worn',
    no_outfit = 'outfit_gone', slow = 'err_slow', inventory_missing = 'err_inventory_missing',
}
local function errText(code)
    local key = ERR[tostring(code)]
    return L(key or 'err_generic')
end

local openOutfits

local function nameDialog(title, default)
    local input = lib.inputDialog(title, {
        { type = 'input', label = L('outfit_name'), default = default, required = true, min = 1,
          max = tonumber((Config.Outfits or {}).nameMax) or 40 },
    })
    return input and input[1] or nil
end

local function wear(o)
    local ok, res = lib.callback.await('multitailor:outfits:wear', false, o.id)
    if not ok then TC.notify(errText(res), 'error') return end
    res = type(res) == 'table' and res or {}
    if (res.missing or 0) > 0 or (res.failed or 0) > 0 then
        TC.notify(L('outfit_missing', (res.missing or 0) + (res.failed or 0)), 'warning')
    else
        TC.notify(L('outfit_worn', o.name), 'success')
    end
end

local function rename(o)
    local name = nameDialog(L('outfit_rename'), o.name)
    if name then
        local ok, err = lib.callback.await('multitailor:outfits:rename', false, o.id, name)
        if ok then TC.notify(L('outfit_renamed'), 'success') else TC.notify(errText(err), 'error') end
    end
    openOutfits()
end

local function delete(o)
    local answer = lib.alertDialog({ header = o.name, content = L('outfit_delete_confirm'), centered = true, cancel = true })
    if answer == 'confirm' then
        local ok, err = lib.callback.await('multitailor:outfits:delete', false, o.id)
        if ok then TC.notify(L('outfit_deleted'), 'success') else TC.notify(errText(err), 'error') end
    end
    openOutfits()
end

local function save()
    local name = nameDialog(L('outfit_save'))
    if name then
        local ok, err = lib.callback.await('multitailor:outfits:save', false, name)
        if ok then TC.notify(L('outfit_saved'), 'success') else TC.notify(errText(err), 'error') end
    end
    openOutfits()
end

openOutfits = function()
    if busy() then return end
    if not invUp() then return TC.notify(L('err_inventory_missing'), 'error') end
    local list = lib.callback.await('multitailor:outfits:list', false) or {}
    local options = {
        { title = L('outfit_save'), description = L('outfit_save_desc'), icon = 'floppy-disk', onSelect = save },
    }
    if #list == 0 then options[#options + 1] = { title = L('outfit_none'), disabled = true } end
    for _, o in ipairs(list) do
        local sub = 'multitailor_outfit_' .. tostring(o.id)
        lib.registerContext({
            id = sub, title = o.name, menu = 'multitailor_outfits',
            options = {
                { title = L('outfit_wear'), icon = 'shirt', onSelect = function() wear(o) end },
                { title = L('outfit_rename'), icon = 'pen', onSelect = function() rename(o) end },
                { title = L('outfit_delete'), icon = 'trash', onSelect = function() delete(o) end },
            },
        })
        options[#options + 1] = { title = o.name, description = L('outfit_pieces', o.pieces or 0), icon = 'shirt', menu = sub, arrow = true }
    end
    lib.registerContext({ id = 'multitailor_outfits', title = L('outfits_title'), options = options })
    lib.showContext('multitailor_outfits')
end

AddEventHandler('MULTItailor:client:openOutfits', function() CreateThread(openOutfits) end)
RegisterNetEvent('MULTItailor:client:openOutfits', function() CreateThread(openOutfits) end)

local oc = (Config.Outfits or {}).command
if type(oc) == 'string' and oc ~= '' then
    RegisterCommand(oc, function() CreateThread(openOutfits) end, false)
end

-- ---------------------------------------------------------------- wardrobe points
local blips = {}
CreateThread(function()
    local w = Config.Wardrobes or {}
    if w.enabled == false then return end
    for i, p in ipairs(w.points or {}) do
        TT.addZone('wardrobe_' .. i, {
            coords = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0), radius = w.radius or 1.2, distance = w.distance or 2.0,
            title = L('opt_wardrobe'),
            options = { { label = L('opt_wardrobe'), icon = 'fa-solid fa-box-archive',
                          canInteract = function() return not TC.view end,
                          onSelect = function() CreateThread(openOutfits) end } },
        })
        if w.blip then
            local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.x, p.y, p.z)
            SetBlipSprite(b, 1496995379, true)
            SetBlipScale(b, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, L('opt_wardrobe'))
            blips[#blips + 1] = b
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    -- toggled-off pieces come back when this resource stops
    if next(hidden) then
        for key in pairs(hidden) do TriggerEvent('vorp_character:Client:OnClothingAdded', key) end
        hidden = {}
        if invUp() then pcall(function() exports[INV]:ReapplyClothing() end) end
    end
end)
