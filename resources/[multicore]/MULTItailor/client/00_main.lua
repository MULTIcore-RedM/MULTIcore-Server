--[[
    Client core: NUI plumbing shared by every window.

    TC.open(view, data)     focus + { action = 'open', view, data, strings }
    TC.close(post)          unfocus (+ tell the page)   TC.view = open view | nil
    TC.update(view, data)   { action = 'update', view, data }
    TC.on(view, act, fn)    NUI 'action' { view, act, ... } -> fn(payload) -> reply table
    TC.onClose(view, fn)    called when that view closes (Esc / close button / TC.close)
    TC.notify(text, type)
    Views: designer, sew, counter, boss, store.
]]
TC = TC or { view = nil, handlers = {}, closers = {} }

local stringsSent = false

function TC.open(view, data)
    TC.view = view
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', view = view, data = data, strings = (not stringsSent) and LocaleTable() or nil })
    stringsSent = true
end

function TC.update(view, data)
    SendNUIMessage({ action = 'update', view = view, data = data })
end

function TC.close(post)
    local view = TC.view
    if not view then return end
    TC.view = nil
    SetNuiFocus(false, false)
    if post ~= false then SendNUIMessage({ action = 'close' }) end
    local fn = TC.closers[view]
    if fn then pcall(fn) end
end

function TC.on(view, act, fn)
    TC.handlers[view] = TC.handlers[view] or {}
    TC.handlers[view][act] = fn
end

function TC.onClose(view, fn) TC.closers[view] = fn end

function TC.focus(on)
    if on then SetNuiFocus(true, true) else SetNuiFocus(false, false) end
end

RegisterNUICallback('action', function(data, cb)
    data = type(data) == 'table' and data or {}
    if data.view ~= TC.view then return cb({ ok = false }) end
    local fn = TC.handlers[data.view] and TC.handlers[data.view][data.act]
    if not fn then return cb({ ok = false }) end
    local ok, res = pcall(fn, data)
    if not ok then
        print(('^1[MULTItailor] NUI %s:%s failed: %s^0'):format(tostring(data.view), tostring(data.act), tostring(res)))
        return cb({ ok = false, error = L('err_generic') })
    end
    cb(res or { ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    TC.close(false)
    cb({ ok = true })
end)

function TC.notify(text, ntype)
    ntype = ntype or 'inform'
    -- @MULTIcore/lib/ui.lua sends lib.notify to MULTIcore's notifications while MULTIcore runs
    lib.notify({ title = L('title'), description = tostring(text or ''), type = ntype, duration = 5000, position = 'top-right' })
end

-- natives shared by the designer, the stores and wearing
TCN = TCN or {}
function TCN.readyToRender(ped)
    local t = GetGameTimer() + 2000
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < t do Wait(0) end
end
function TCN.updateVariation(ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
end
function TCN.removeTag(ped, tag) Citizen.InvokeNative(0xD710A5007C2AC539, ped, joaat(tag), 0) end
function TCN.applyHash(ped, hash, isBoots)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, false, false)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, true, false)
    if not isBoots then Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, hash, joaat('base'), 0, true, 1) end
end
function TCN.setTint(ped, tag, palette, t0, t1, t2)
    local want = joaat(tag)
    local n = Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger())
    for i = 0, (n or 0) - 1 do
        local cat = Citizen.InvokeNative(0x9B90842304C938A7, ped, i, 0, Citizen.ResultAsInteger())
        if cat == want then
            local drawable, albedo, normal, material = Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, i,
                Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
            Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, drawable, albedo, normal, material, palette, t0, t1, t2)
            return true
        end
    end
    Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, want, palette, t0, t1, t2)
    return false
end

---Clothing catalogue on the client: read the appearance resource's file, else ask the server once.
function TCN.catalogue()
    local cat, err = TS.catalogue()
    if cat then return cat end
    local remote = lib.callback.await('multitailor:catalogue', false)
    TS.resetCatalogue()
    if TS.setCatalogue(remote) then return TS.catalogue() end
    return nil, err
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if TC.view then SetNuiFocus(false, false) end
end)
