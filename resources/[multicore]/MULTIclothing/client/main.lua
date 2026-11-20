-- ============================================================
-- MULTIclothing :: client main
-- Blips, store / wardrobe interaction points, shared helpers.
-- ============================================================

MC = MC or {}
MC.RSGCore = exports['rsg-core']:GetCoreObject()

local blips, prompts, zones = {}, {}, {}

-- every notification goes through MULTIcore's notify system
function MC.Notify(msg, kind)
    exports.MULTIcore:Notify({ text = msg, title = _L('toggles_title'), type = kind or 'info' })
end

-- server reason codes ('too_far', 'no_cash', 'busy', 'failed') are locale keys
function MC.Error(code)
    MC.Notify(_L(type(code) == 'string' and code or 'failed'), 'error')
end

function MC.LoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

function MC.Busy()
    local ped = PlayerPedId()
    return MC.storeOpen or IsEntityDead(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
end

function MC.Copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = MC.Copy(v) end
    return o
end

-- the logged-in character's saved look straight from the server
function MC.SavedLook()
    local look = lib.callback.await('MULTIcore:look:get', false)
    if type(look) ~= 'table' then return nil end
    look.skin = type(look.skin) == 'table' and look.skin or {}
    look.comps = type(look.comps) == 'table' and look.comps or {}
    return look
end

-- ---------------------------------------------------------------
-- Store menu: browse or outfits
-- ---------------------------------------------------------------

function MC.OpenStoreMenu(storeId)
    if not MC.LoggedIn() or MC.Busy() then return end
    local store = Config.Stores[storeId]
    if not store then return end
    lib.registerContext({
        id = 'multiclothing_store',
        title = _L(store.name),
        options = {
            { title = _L('menu_store'), description = _L('menu_store_desc'), icon = Config.Icons.Store,
              onSelect = function() MC.OpenStore(storeId) end },
            { title = _L('menu_outfits'), description = _L('menu_outfits_desc'), icon = Config.Icons.Outfits,
              onSelect = function() MC.OpenOutfits() end },
        },
    })
    lib.showContext('multiclothing_store')
end

AddEventHandler('MULTIclothing:client:storePoint', function(storeId) MC.OpenStoreMenu(storeId) end)
AddEventHandler('MULTIclothing:client:wardrobePoint', function()
    if not MC.LoggedIn() or MC.Busy() then return end
    MC.OpenOutfits()
end)

-- ---------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------

local function addBlip(coords, sprite, name)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.Blips.Style, coords.x, coords.y, coords.z) -- BLIP_ADD_FOR_COORDS
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, Config.Blips.Scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name) -- _SET_BLIP_NAME
    blips[#blips + 1] = blip
end

-- ---------------------------------------------------------------
-- Interaction points
-- ---------------------------------------------------------------

local function addPoint(mode, name, coords, label, icon, event, args)
    if mode == 'target' then
        zones[#zones + 1] = MCI.AddZone({
            coords = coords,
            radius = Config.TargetRadius,
            options = { {
                name = name,
                label = label,
                icon = icon,
                distance = Config.TargetDistance,
                onSelect = function() TriggerEvent(event, table.unpack(args)) end,
            } },
        })
    else
        MCI.AddPrompt(name, coords, Config.PromptKey, label,
            { type = 'client', event = event, args = args }, Config.PromptDistance)
        prompts[#prompts + 1] = name
    end
end

-- MULTItarget (Config.Interact 'auto' / 'target') or hold-key prompts, see @MULTIcore/lib/interact.lua
MCI.Run(Config.Interact, function(mode)
    for id, s in pairs(Config.Stores) do
        addPoint(mode, 'multiclothing_store_' .. id, s.coords, _L('prompt_store'), Config.TargetIconStore,
            'MULTIclothing:client:storePoint', { id })
    end
    for i, coords in ipairs(Config.Wardrobes) do
        addPoint(mode, 'multiclothing_wardrobe_' .. i, coords, _L('prompt_wardrobe'), Config.TargetIconWardrobe,
            'MULTIclothing:client:wardrobePoint', {})
    end
end, function()
    for _, z in ipairs(zones) do MCI.RemoveZone(z) end
    zones = {}
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    prompts = {}
end)

CreateThread(function()
    for _, s in pairs(Config.Stores) do
        if Config.Blips.Stores and s.blip then addBlip(s.coords, Config.Blips.StoreSprite, _L('blip_store')) end
    end
    for _, coords in ipairs(Config.Wardrobes) do
        if Config.Blips.Wardrobes then addBlip(coords, Config.Blips.WardrobeSprite, _L('blip_wardrobe')) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    -- MULTItarget drops this script's zones by itself when it stops
end)
