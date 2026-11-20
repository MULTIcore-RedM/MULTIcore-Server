-- ============================================================
-- MULTIclothing :: client quick toggles
-- Take pieces off / put them back on from the saved look. Nothing is saved.
-- Also answers rsg-wardrobe's client exports and events for RSG v2 scripts.
-- ============================================================

local off = {} -- category -> true while taken off

-- saved comps without a server round trip (MULTIcore's cached look)
local function cachedComps()
    local look = exports.MULTIcore:GetLook()
    return (type(look) == 'table' and type(look.comps) == 'table') and look.comps or {}
end

local function sexNow()
    local look = exports.MULTIcore:GetLook()
    local s = type(look) == 'table' and type(look.skin) == 'table' and look.skin.sex
    if s == 'male' or s == 'female' then return s end
    return IsPedMale(PlayerPedId()) and 'male' or 'female'
end

-- every category the clothing store deals with, for the current sex
local function clothingCats()
    local data = exports.MULTIcore:GetData()
    local list = data and data.Clothes and data.Clothes[sexNow()] or {}
    local out = {}
    for cat in pairs(list) do
        if not Config.NotSold[cat] then out[#out + 1] = cat end
    end
    return out
end

local function setCats(cats, on, comps)
    local ped = PlayerPedId()
    for _, cat in ipairs(cats) do
        if on then
            if off[cat] and comps[cat] then exports.MULTIcore:ApplyComp(ped, cat, comps[cat]) end
            off[cat] = nil
        elseif comps[cat] then
            exports.MULTIcore:RemoveComp(ped, cat)
            off[cat] = true
        end
    end
end

local function anyOwned(cats, comps)
    for _, cat in ipairs(cats) do if comps[cat] then return true end end
    return false
end

local function anyOff(cats)
    for _, cat in ipairs(cats) do if off[cat] then return true end end
    return false
end

-- puts every taken-off piece back on, or only forgets the state
-- (forget = true, when a whole look is about to be applied anyway)
function MC.ResetToggles(forget)
    if forget or not next(off) then off = {} return end
    local comps = cachedComps()
    local cats = {}
    for cat in pairs(off) do cats[#cats + 1] = cat end
    setCats(cats, true, comps)
    off = {}
end

-- ---------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------

local function openMenu()
    if not MC.LoggedIn() or MC.Busy() then return MC.Notify(_L('busy'), 'error') end
    local look = MC.SavedLook()
    if not look then return MC.Error('failed') end
    local comps = look.comps
    local options = {}
    for _, item in ipairs(Config.Toggles.Items) do
        local owned = anyOwned(item.cats, comps)
        local isOff = anyOff(item.cats)
        options[#options + 1] = {
            title = _L('toggle_' .. item.id),
            icon = item.icon,
            description = (not owned and _L('toggle_none')) or (isOff and _L('toggle_off')) or _L('toggle_on'),
            disabled = not owned,
            onSelect = function()
                setCats(item.cats, isOff, comps)
                openMenu()
            end,
        }
    end
    options[#options + 1] = {
        title = _L('toggle_all'), icon = Config.Icons.AllOn, disabled = not next(off),
        onSelect = function() MC.ResetToggles() openMenu() end,
    }
    lib.registerContext({ id = 'multiclothing_toggles', title = _L('toggles_title'), options = options })
    lib.showContext('multiclothing_toggles')
end

if Config.Toggles.Enabled then
    RegisterCommand(Config.Toggles.Command, openMenu, false)
end

-- a fresh character or a reloaded look starts fully dressed
RegisterNetEvent('MULTIcore:client:characterSelected', function() off = {} end)

-- ---------------------------------------------------------------
-- rsg-wardrobe client API (names and arguments as in RSG v2 rsg-wardrobe)
--   ToggleClothing(name)   name = rsg-wardrobe clothing name ('hat', 'glove', 'shirt' ...)
--   RemoveAllClothing()
--   IsWearing(name)        -> boolean
-- ---------------------------------------------------------------

local function catsFor(name)
    if type(name) ~= 'string' then return {} end
    return MCAlias.WardrobeNames[name] or { name }
end

local function toggleClothing(name)
    if MC.storeOpen then return end
    local cats = catsFor(name)
    setCats(cats, anyOff(cats), cachedComps())
end

local function removeAllClothing()
    if MC.storeOpen then return end
    setCats(clothingCats(), false, cachedComps())
end

local function dressPlayer()
    if MC.storeOpen then return end
    off = {}
    local comps = cachedComps()
    if next(comps) then exports.MULTIcore:ApplyComps(PlayerPedId(), comps) end
end

local function isWearing(name)
    local comps = cachedComps()
    for _, cat in ipairs(catsFor(name)) do
        if comps[cat] and not off[cat] then return true end
    end
    return false
end

MCAlias.Wardrobe('ToggleClothing', toggleClothing)
MCAlias.Wardrobe('RemoveAllClothing', removeAllClothing)
MCAlias.Wardrobe('IsWearing', isWearing)
-- client-side conveniences under the server export names
MCAlias.Wardrobe('DressPlayer', dressPlayer)
MCAlias.Wardrobe('RemovePlayerClothing', removeAllClothing)

-- rsg-wardrobe's own net events (its server exports fire these)
RegisterNetEvent('rsg-wardrobe:client:OnOffClothing', toggleClothing)
RegisterNetEvent('rsg-wardrobe:client:removeAllClothing', removeAllClothing)
RegisterNetEvent('MULTIclothing:client:dress', dressPlayer)
