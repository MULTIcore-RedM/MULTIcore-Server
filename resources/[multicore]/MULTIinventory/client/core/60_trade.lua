-- ============================================================
-- MULTIinventory :: trading between two players (client)
-- GPL v3, part of MULTIcore.
--
-- Ways to offer a trade: /trade (nearest player, or /trade <server id>),
-- the Trade button on the satchel page, and "Offer a trade" on a player
-- through MULTItarget. The asked player answers in an ox_lib dialog.
-- The trade window is the satchel page in trade mode: the satchel on the
-- left, both offers and the cash on the right. The server decides
-- everything (server/core/70_trade.lua); this file only shows and asks.
-- ============================================================

MIC.Trade = nil            -- the trade as the server last sent it (Inv.TradeView), nil = none

local pendingFrom = nil    -- server id of the player whose request dialog is up

--- The trade made ready for the page (item definitions merged in).
function MIC.TradeForNui(t)
    if type(t) ~= 'table' then return nil end
    local function side(s)
        s = type(s) == 'table' and s or {}
        local items = {}
        for _, l in ipairs(s.items or {}) do
            local it = MIC.ItemForNui({ slot = l.slot, name = l.name, amount = l.amount, info = l.info or {} })
            it.from = l.from
            it.equipped = false
            items[#items + 1] = it
        end
        return { items = items, cash = tonumber(s.cash) or 0, accepted = s.accepted == true }
    end
    return {
        partner = t.partner,
        mine = side(t.mine),
        theirs = side(t.theirs),
        myCash = tonumber(t.myCash) or 0,
        maxItems = tonumber(t.maxItems) or 12,
        maxCash = tonumber(t.maxCash) or 0,
        acceptDelay = tonumber(t.acceptDelay) or 0,
    }
end

-- ---------------------------------------------------------------
-- asking
-- ---------------------------------------------------------------

local function requestTrade(serverId)
    if not MIC.Cfg('Trade.Enabled', true) or not MIC.CanUse(true) then return end
    if not serverId then
        local pid = MIC.NearestPlayer(MIC.Cfg('Trade.Distance', 3.0))
        if not pid then return MIC.Notify(_L('no_player_near'), 'error') end
        serverId = GetPlayerServerId(pid)
    end
    TriggerServerEvent('MULTIinventory:server:tradeRequest', serverId)
end
MIC.RequestTrade = requestTrade

RegisterCommand(MIC.Cfg('Trade.Command', 'trade'), function(_, args)
    requestTrade(tonumber(args and args[1]))
end, false)

-- MULTItarget: "Offer a trade" on every other player. MCI.Run (@MULTIcore/lib/interact.lua) waits
-- for MULTItarget at start and adds the option again when MULTItarget starts later or restarts.
-- Without MULTItarget, /trade and the satchel's Trade button still work (no prompt on players).
if MIC.Cfg('Trade.Enabled', true) and MIC.Cfg('Trade.UseTarget', true) then
    MCI.Run('auto', function(mode)
        if mode ~= 'target' then return end
        exports.MULTItarget:addGlobalPlayer({ {
            name = 'multiinventory_trade',
            label = _L('trade_target'),
            icon = MIC.Cfg('Trade.TargetIcon', 'fas fa-handshake'),
            distance = math.min(MIC.Cfg('Trade.Distance', 3.0), 2.5), -- the server allows Trade.Distance
            onSelect = function(data)
                local ped = data and data.entity
                if not ped or not DoesEntityExist(ped) then return end
                local pid = NetworkGetPlayerIndexFromPed(ped)
                if pid and pid ~= -1 then requestTrade(GetPlayerServerId(pid)) end
            end,
        } })
        MCI.Count('targets', 1)
    end, function(mode)
        if mode ~= 'target' then return end
        if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeGlobalPlayer('multiinventory_trade') end) end
        MCI.Count('targets', -1)
    end)
end

-- ---------------------------------------------------------------
-- being asked
-- ---------------------------------------------------------------

RegisterNetEvent('MULTIinventory:client:tradeRequest', function(from, name, seconds)
    from = tonumber(from)
    if not from then return end
    if pendingFrom then lib.closeAlertDialog() end
    pendingFrom = from
    CreateThread(function()
        local answer = lib.alertDialog({
            header = _L('trade_title'),
            content = _L('trade_ask', tostring(name or from), tonumber(seconds) or 0),
            centered = true,
            cancel = true,
            labels = { confirm = _L('trade_yes'), cancel = _L('trade_no') },
        })
        if pendingFrom ~= from then return end   -- ran out or replaced while the dialog was up
        pendingFrom = nil
        TriggerServerEvent('MULTIinventory:server:tradeAnswer', from, answer == 'confirm')
    end)
end)

RegisterNetEvent('MULTIinventory:client:tradeRequestGone', function(from)
    if pendingFrom ~= nil and pendingFrom == tonumber(from) then
        pendingFrom = nil
        lib.closeAlertDialog()
    end
end)

-- ---------------------------------------------------------------
-- the trade window
-- ---------------------------------------------------------------

RegisterNetEvent('MULTIinventory:client:tradeOpen', function(own, defs, view, viewDefs)
    if type(view) ~= 'table' then return end
    MIC.MergeDefs(defs)
    MIC.MergeDefs(viewDefs)
    if type(own) == 'table' then MIC.SetInv(own, true) end
    MIC.Other = nil
    MIC.Trade = view
    MIC.FireInvChange()
    MIC.SendStatic()
    MIC.IsOpen = true
    SetNuiFocus(true, true)
    TriggerEvent('MULTIinventory:client:stateChange', true)
    SendNUIMessage({ action = 'open', player = MIC.InvForNui(MIC.Inv), trade = MIC.TradeForNui(view) })
end)

RegisterNetEvent('MULTIinventory:client:tradeUpdate', function(view, viewDefs)
    if type(view) ~= 'table' then return end
    MIC.MergeDefs(viewDefs)
    MIC.Trade = view
    MIC.PushPage()
end)

RegisterNetEvent('MULTIinventory:client:tradeEnd', function()
    if not MIC.Trade then return end
    MIC.Trade = nil
    MIC.Close(false)
end)

-- the page's trade buttons
local function answer(cb, ok, err)
    if not ok then MIC.Error(err) end
    cb({ ok = ok == true })
end

RegisterNUICallback('tradeStart', function(_, cb)
    cb({})
    requestTrade(nil)
end)

RegisterNUICallback('tradeItem', function(data, cb)
    if not MIC.Trade or type(data) ~= 'table' then return cb({ ok = false }) end
    local ok, err = lib.callback.await('MULTIinventory:server:tradeItem', false, tonumber(data.slot), tonumber(data.amount) or 0)
    answer(cb, ok, err)
end)

RegisterNUICallback('tradeCash', function(data, cb)
    if not MIC.Trade or type(data) ~= 'table' then return cb({ ok = false }) end
    local ok, err = lib.callback.await('MULTIinventory:server:tradeCash', false, tostring(data.amount or '0'))
    answer(cb, ok, err)
end)

RegisterNUICallback('tradeAccept', function(data, cb)
    if not MIC.Trade then return cb({ ok = false }) end
    local ok, err = lib.callback.await('MULTIinventory:server:tradeAccept', false, not (type(data) == 'table' and data.state == false))
    answer(cb, ok, err)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GetResourceState('MULTItarget') == 'started' then
        pcall(function() exports.MULTItarget:removeGlobalPlayer('multiinventory_trade') end)
    end
end)
