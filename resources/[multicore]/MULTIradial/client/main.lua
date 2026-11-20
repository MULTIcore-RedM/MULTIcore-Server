-- ============================================================
-- MULTIradial :: client
-- Builds the menu from Config.Menu plus the buttons other scripts add
-- (exports['rsg-radialmenu']:AddOption / RemoveOption, RSG v2's API), sends a
-- plain copy to the page and runs the button the player picks. Only buttons that
-- are in the tree built here can run; the page only names them by id.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local open = false
local nodes = {}        -- [id] = button (with its functions) of the menu that is open now
local dynamic = {}      -- [key] = button added by another script (RSG format)
local dynOrder = {}     -- keys in the order they were added
local nextKey = 0

-- ------------------------------------------------------------
-- buttons from other scripts (RSG v2 rsg-radialmenu API)
-- ------------------------------------------------------------
local function AddOption(data, id)
    if type(data) ~= 'table' then return end
    if id == nil then nextKey = nextKey + 1 id = nextKey end
    if dynamic[id] == nil then dynOrder[#dynOrder + 1] = id end
    dynamic[id] = data
    return id
end

local function RemoveOption(id)
    if id == nil or dynamic[id] == nil then return end
    dynamic[id] = nil
    for i = #dynOrder, 1, -1 do if dynOrder[i] == id then table.remove(dynOrder, i) end end
end

exports('AddOption', AddOption)
exports('RemoveOption', RemoveOption)
-- the same exports under the old name (provide does not carry exports over)
AddEventHandler('__cfx_export_rsg-radialmenu_AddOption', function(setCB) setCB(AddOption) end)
AddEventHandler('__cfx_export_rsg-radialmenu_RemoveOption', function(setCB) setCB(RemoveOption) end)

-- ------------------------------------------------------------
-- building the tree
-- ------------------------------------------------------------
local function jobName()
    local pd = RSGCore.Functions.GetPlayerData() or {}
    return pd.job and pd.job.name or nil
end

local function allowed(b)
    if type(b) ~= 'table' then return false end
    if b.resource and GetResourceState(b.resource) ~= 'started' then return false end
    if b.job then
        local j, ok = jobName(), false
        for _, n in ipairs(type(b.job) == 'table' and b.job or { b.job }) do if n == j then ok = true end end
        if not ok then return false end
    end
    if b.canOpen then
        local ok, res = pcall(b.canOpen)
        if not ok or not res then return false end
    end
    return true
end

local function textOf(b)
    if b.label then return _L(b.label) end
    return tostring(b.title or b.label or '?')
end

-- copy of a list for the page, with ids; long lists get a "More" button
local function build(list, prefix, out)
    local kept = {}
    for _, b in ipairs(list) do
        if allowed(b) then
            if b.items then
                local sub = build(b.items, '', nil)
                if #sub > 0 then kept[#kept + 1] = { b = b, sub = b.items } end
            else
                kept[#kept + 1] = { b = b }
            end
        end
    end
    local per = math.max(2, Config.PerPage or 8)
    if #kept > per then
        local rest = {}
        for i = per, #kept do rest[#rest + 1] = kept[i].b end
        for i = #kept, per, -1 do kept[i] = nil end
        kept[per] = { b = { label = 'more', icon = 'ellipsis', items = rest }, sub = rest }
    end
    local page = {}
    for i, k in ipairs(kept) do
        local id = prefix .. i
        local entry = { id = id, text = textOf(k.b), icon = k.b.icon or 'circle' }
        if k.sub then
            entry.items = build(k.sub, id .. '.', out)
        end
        if out then out[id] = k.b end
        page[#page + 1] = entry
    end
    return page
end

local function tree()
    local list = {}
    for _, b in ipairs(Config.Menu) do list[#list + 1] = b end
    for _, k in ipairs(dynOrder) do if dynamic[k] then list[#list + 1] = dynamic[k] end end
    nodes = {}
    return build(list, '', nodes)
end

-- ------------------------------------------------------------
-- open / close
-- ------------------------------------------------------------
local function canOpen()
    if not LocalPlayer.state.isLoggedIn or IsPauseMenuActive() then return false end
    local md = (RSGCore.Functions.GetPlayerData() or {}).metadata or {}
    return not md.isdead and not md.ishandcuffed
end

local function setOpen(on)
    if on == open then return end
    open = on
    if on then
        TriggerEvent('rsg-radialmenu:client:onRadialmenuOpen')
        SendNUIMessage({ action = 'open', items = tree(), scale = Config.Scale or 1.0, locale = _LT() })
        SetNuiFocus(true, true)
        SetCursorLocation(0.5, 0.5)
    else
        SendNUIMessage({ action = 'close' })
        SetNuiFocus(false, false)
        TriggerEvent('rsg-radialmenu:client:onRadialmenuClose')
    end
end

local function toggle()
    if open then return setOpen(false) end
    if canOpen() then setOpen(true) end
end

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, toggle, false)
end

CreateThread(function()
    local key = RSGCore.Shared.Keybinds[Config.Keybind]
    if not key then return print(('^3[MULTIradial] unknown key %s in Config.Keybind^7'):format(tostring(Config.Keybind))) end
    while true do
        Wait(0)
        if not open then
            if IsControlJustPressed(0, key) and canOpen() then setOpen(true) end
        elseif Config.HoldToOpen and (IsControlJustReleased(0, key) or IsDisabledControlJustReleased(0, key)) then
            setOpen(false)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)

-- ------------------------------------------------------------
-- running a button
-- ------------------------------------------------------------
local function run(b)
    if b.action then return b.action(b) end
    if b.clothing then return TriggerEvent('rsg-wardrobe:client:OnOffClothing', b.clothing) end
    if b.dress then return TriggerEvent('MULTIclothing:client:dress') end
    if b.undress then return TriggerEvent('rsg-wardrobe:client:removeAllClothing') end
    if b.command then return ExecuteCommand(b.command) end
    -- RSG v2 option format
    if b.type == 'client' and b.event then return TriggerEvent(b.event, b) end
    if b.type == 'server' and b.event then return TriggerServerEvent(b.event, b) end
    if b.type == 'command' and b.event then return ExecuteCommand(b.event) end
    if b.type == 'rsgcommand' and b.event then return TriggerServerEvent('RSGCore:CallCommand', b.event, b) end
    if b.event then
        if b.server then TriggerServerEvent(b.event, b) else TriggerEvent(b.event, b) end
    end
end

RegisterNUICallback('select', function(data, cb)
    cb('ok')
    if not open or type(data) ~= 'table' then return end
    local b = nodes[tostring(data.id)]
    if not b or b.items then return end
    -- clothing toggles keep the menu open so several pieces can be switched
    local keep = b.shouldClose == false or b.clothing ~= nil
    if not keep then setOpen(false) end
    if not canOpen() then return end
    local ok, err = pcall(run, b)
    if not ok then print(('^1[MULTIradial] button %s failed: %s^7'):format(tostring(data.id), tostring(err))) end
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    setOpen(false)
end)

-- the player died, was cuffed or logged out while the menu was open
CreateThread(function()
    while true do
        Wait(500)
        if open and not canOpen() then setOpen(false) end
    end
end)
