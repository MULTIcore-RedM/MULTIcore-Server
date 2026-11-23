-- ============================================================
-- MULTIhelpers :: QB-style menu
-- (stands in for rsg-menu, qb-menu and qbr-menu: one API)
--
--   exports['rsg-menu']:openMenu({
--       { header = 'Stable', isMenuHeader = true },
--       { header = 'Buy a horse', txt = 'See the horses for sale', icon = 'fas fa-horse',
--         params = { event = 'stable:client:buy', args = { id = 1 } } },
--       { header = 'Sell', txt = 'Not today', disabled = true },
--       { header = 'Close', params = { event = 'rsg-menu:client:closeMenu' } },
--   }, onClose)                                   -- onClose: qbr-menu extra, optional
--   exports['rsg-menu']:closeMenu()
--   exports['rsg-menu']:showHeader(menu)          -- opens it like openMenu
--   TriggerEvent('rsg-menu:client:openMenu', menu) / ('rsg-menu:client:closeMenu')
--   (same for qb-menu:... and qbr-menu:..., also from the server)
--
-- Row fields: header, txt (or text), icon, isMenuHeader, disabled, hidden,
-- params = { event, args, isServer, isCommand, isQBCommand, isAction }.
-- Drawn with MULTIcore's context menu, so it follows the UI presets.
-- Own code, written from the public API description. GPL v3, part of MULTIcore.
-- ============================================================

local NAMES = { 'rsg-menu', 'qb-menu', 'qbr-menu' }
local CTX_ID = 'MULTIhelpers:qbmenu'

local function str(v)
    if v == nil or v == '' then return nil end
    return tostring(v)
end

--- what a clicked row does, as the original routes params
local function route(p, via)
    local ev, args = p.event, p.args
    if p.isAction then
        if Helpers.Callable(ev) then Helpers.SafeCall(ev, args) end
    elseif type(ev) ~= 'string' or ev == '' then
        return
    elseif p.isServer then
        TriggerServerEvent(ev, args)
    elseif p.isCommand then
        ExecuteCommand(ev)
    elseif p.isQBCommand then
        -- a core command run on the server, the way each core takes it
        TriggerServerEvent(via == 'rsg-menu' and 'RSGCore:CallCommand' or 'QBCore:CallCommand', ev, args)
    else
        TriggerEvent(ev, args)
    end
end

local function openMenu(via, menu, onClose)
    if type(menu) ~= 'table' then return end
    local title, options = nil, {}
    for i, b in ipairs(menu) do
        if type(b) == 'table' and not b.hidden then
            local text = str(b.txt or b.text)
            if b.isMenuHeader then
                -- the first header row is the menu's title; its sub-line stays as a plain row
                if not title and i <= 2 then
                    title = str(b.header) or ''
                    if text then options[#options + 1] = { title = text, readOnly = true } end
                else
                    options[#options + 1] = { title = str(b.header) or '', description = text, readOnly = true }
                end
            else
                local p = type(b.params) == 'table' and b.params or nil
                local o = {
                    title = str(b.header) or '',
                    description = text,
                    icon = type(b.icon) == 'string' and b.icon or nil,
                    disabled = b.disabled and true or false,
                }
                if p and (p.event ~= nil) and not b.disabled then
                    o.onSelect = function() route(p, via) end
                else
                    o.readOnly = not b.disabled
                end
                options[#options + 1] = o
            end
        end
    end
    exports.MULTIcore:registerContext({
        id = CTX_ID,
        title = title or '',
        options = options,
        onExit = Helpers.Callable(onClose) and function() Helpers.SafeCall(onClose) end or nil,
    })
    exports.MULTIcore:showContext(CTX_ID)
end

local function closeMenu()
    if exports.MULTIcore:getOpenContextMenu() == CTX_ID then
        exports.MULTIcore:hideContext(false)
    end
end

for _, name in ipairs(NAMES) do
    local function open(menu, onClose) openMenu(name, menu, onClose) end
    Helpers.ExportAs('openMenu', open, { name })
    -- showHeader opens the menu without focus in the original; here it opens like openMenu
    Helpers.ExportAs('showHeader', open, { name })
    Helpers.ExportAs('closeMenu', closeMenu, { name })
    Helpers.On(name, name .. ':client:openMenu', function(menu) openMenu(name, menu) end, true)
    Helpers.On(name, name .. ':client:closeMenu', closeMenu, true)
end

-- and under MULTIhelpers' own name
exports('openMenu', function(menu, onClose) openMenu('qb-menu', menu, onClose) end)
exports('closeMenu', closeMenu)
