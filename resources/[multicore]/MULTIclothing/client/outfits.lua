-- ============================================================
-- MULTIclothing :: client outfits (ox_lib menus)
-- Save the saved look as a named outfit, wear / rename / delete outfits.
-- ============================================================


local function wear(id)
    local ok, err = lib.callback.await('MULTIclothing:outfits:wear', false, id)
    if not ok then return MC.Error(err) end
    local look = MC.SavedLook()
    if look then
        MC.ResetToggles(true)
        exports.MULTIcore:ApplyLook(PlayerPedId(), look)
    end
    MC.Notify(_L('outfit_worn'), 'success')
end

local function rename(o)
    local input = lib.inputDialog(_L('outfit_rename'), {
        { type = 'input', label = _L('outfit_name'), default = o.name, required = true, min = 1, max = Config.Outfits.NameMax },
    })
    if not input or not input[1] then return MC.OpenOutfits() end
    if lib.callback.await('MULTIclothing:outfits:rename', false, o.id, input[1]) then
        MC.Notify(_L('outfit_renamed'), 'success')
    else
        MC.Error('failed')
    end
    MC.OpenOutfits()
end

local function delete(o)
    local answer = lib.alertDialog({ header = o.name, content = _L('outfit_delete_confirm'), centered = true, cancel = true })
    if answer ~= 'confirm' then return MC.OpenOutfits() end
    if lib.callback.await('MULTIclothing:outfits:delete', false, o.id) then
        MC.Notify(_L('outfit_deleted'), 'success')
    else
        MC.Error('failed')
    end
    MC.OpenOutfits()
end

local function save()
    local input = lib.inputDialog(_L('outfit_save'), {
        { type = 'input', label = _L('outfit_name'), required = true, min = 1, max = Config.Outfits.NameMax },
    })
    if not input or not input[1] then return MC.OpenOutfits() end
    local ok, err = lib.callback.await('MULTIclothing:outfits:save', false, input[1])
    if ok then
        MC.Notify(_L('outfit_saved'), 'success')
    elseif err == 'full' then
        MC.Notify(_L('outfit_full', Config.Outfits.Max), 'error')
    else
        MC.Error(err)
    end
    MC.OpenOutfits()
end

function MC.OpenOutfits()
    if not MC.LoggedIn() or MC.storeOpen then return end
    local list = lib.callback.await('MULTIclothing:outfits:list', false) or {}
    local options = {
        { title = _L('outfit_save'), description = _L('outfit_save_desc'), icon = Config.Icons.Save, onSelect = save },
    }
    if #list == 0 then
        options[#options + 1] = { title = _L('outfit_none'), disabled = true }
    end
    for _, o in ipairs(list) do
        local sub = 'multiclothing_outfit_' .. o.id
        lib.registerContext({
            id = sub,
            title = o.name,
            menu = 'multiclothing_outfits',
            options = {
                { title = _L('outfit_wear'), icon = Config.Icons.Outfit, onSelect = function() wear(o.id) end },
                { title = _L('outfit_rename'), icon = Config.Icons.Rename, onSelect = function() rename(o) end },
                { title = _L('outfit_delete'), icon = Config.Icons.Delete, onSelect = function() delete(o) end },
            },
        })
        options[#options + 1] = { title = o.name, icon = Config.Icons.Outfit, menu = sub, arrow = true }
    end
    lib.registerContext({ id = 'multiclothing_outfits', title = _L('outfits_title'), options = options })
    lib.showContext('multiclothing_outfits')
end

if Config.Outfits.Command then
    RegisterCommand(Config.Outfits.CommandName, function()
        if MC.Busy() then return MC.Notify(_L('busy'), 'error') end
        MC.OpenOutfits()
    end, false)
end
