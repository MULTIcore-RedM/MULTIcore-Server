--[[
    /tailorstores (admin): ox_lib menu to move, add, rename, hide, reprice or remove clothes stores
    live. The server checks the ACE / group again on every action and saves to multitailor_stores.
]]
local function act(payload)
    local res = lib.callback.await('multitailor:admin:store', false, payload)
    if not res or not res.ok then
        TC.notify(res and res.error or L('err_generic'), 'error')
        return nil
    end
    TC.notify(L('admin_saved'), 'success')
    return res
end

local openList

local function openStore(s)
    local opts = {}
    if s.deleted then
        opts[#opts + 1] = { title = L('admin_restore'), icon = 'rotate-left', onSelect = function() act({ action = 'reset', id = s.id }) openList() end }
    else
        opts = {
            { title = L('admin_teleport'), icon = 'location-arrow', onSelect = function()
                SetEntityCoords(PlayerPedId(), s.clerk.x + 0.0, s.clerk.y + 0.0, s.clerk.z + 1.0, false, false, false, false)
            end },
            { title = L('admin_move_here'), description = L('admin_move_here_desc'), icon = 'arrows-up-down-left-right',
              onSelect = function() act({ action = 'move', id = s.id }) openList() end },
            { title = L('admin_rename'), icon = 'pen', onSelect = function()
                local input = lib.inputDialog(L('admin_rename'), { { type = 'input', label = L('admin_label'), default = s.label, required = true, max = 48 } })
                if input and input[1] then act({ action = 'rename', id = s.id, label = input[1] }) end
                openList()
            end },
            { title = s.enabled and L('admin_disable') or L('admin_enable'), icon = 'power-off',
              onSelect = function() act({ action = 'toggle', id = s.id }) openList() end },
            { title = s.blip and L('admin_blip_off') or L('admin_blip_on'), icon = 'map-pin',
              onSelect = function() act({ action = 'blip', id = s.id }) openList() end },
            { title = L('admin_price'), description = ('x%.2f'):format(s.priceMultiplier or 1.0), icon = 'dollar-sign', onSelect = function()
                local input = lib.inputDialog(L('admin_price'), { { type = 'number', label = L('admin_mult'), default = s.priceMultiplier or 1.0,
                    min = 0.1, max = 10, step = 0.05, precision = 2, required = true } })
                if input and input[1] then act({ action = 'price', id = s.id, mult = input[1] }) end
                openList()
            end },
            { title = L('admin_model'), description = s.model, icon = 'user', onSelect = function()
                local input = lib.inputDialog(L('admin_model'), { { type = 'input', label = 'ped model', default = s.model, required = true, max = 48 } })
                if input and input[1] then act({ action = 'model', id = s.id, model = input[1] }) end
                openList()
            end },
        }
        if s.overridden and s.config then
            opts[#opts + 1] = { title = L('admin_reset'), icon = 'rotate-left', onSelect = function() act({ action = 'reset', id = s.id }) openList() end }
        end
        opts[#opts + 1] = { title = L('admin_delete'), icon = 'trash', onSelect = function()
            local ok = lib.alertDialog({ header = L('admin_delete'), content = L('admin_delete_confirm', s.label), centered = true, cancel = true })
            if ok == 'confirm' then act({ action = 'delete', id = s.id }) end
            openList()
        end }
    end
    lib.registerContext({ id = 'multitailor_store_' .. s.id, title = s.label, menu = 'multitailor_stores', options = opts })
    lib.showContext('multitailor_store_' .. s.id)
end

openList = function()
    local res = lib.callback.await('multitailor:admin:stores', false)
    if not res then return TC.notify(L('err_no_access'), 'error') end
    local opts = {
        { title = L('admin_add'), description = L('admin_add_desc'), icon = 'plus', onSelect = function()
            local input = lib.inputDialog(L('admin_add'), {
                { type = 'input', label = L('admin_label'), required = true, max = 48 },
                { type = 'input', label = L('admin_town'), required = false, max = 32 },
            })
            if input and input[1] then act({ action = 'create', label = input[1], town = input[2] }) end
            openList()
        end },
    }
    for _, s in ipairs(res.stores or {}) do
        local state = s.deleted and L('admin_state_deleted') or (s.enabled and L('admin_state_open') or L('admin_state_closed'))
        opts[#opts + 1] = { title = s.label, description = ('%s · %s%s'):format(s.town or s.id, state, s.config and '' or ' · ' .. L('admin_state_added')),
            icon = 'shirt', arrow = true, onSelect = function() openStore(s) end }
    end
    lib.registerContext({ id = 'multitailor_stores', title = L('admin_title'), options = opts })
    lib.showContext('multitailor_stores')
end

RegisterNetEvent('MULTItailor:adminMenu', function() openList() end)
