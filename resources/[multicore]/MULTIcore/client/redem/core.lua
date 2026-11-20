-- ============================================================
-- MULTIcore :: RedEM:RP face - the client core object
-- exports['redem_roleplay']:RedEM() / :GetPlayerData() on the client.
-- Written from RedEM:RP's public API (the 2023 redem_roleplay); no
-- RedEM:RP code is used. GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

MULTI = MULTI or {}

local RedEM = { Functions = {}, PlayerData = { isLoggedIn = false } }

local function notify(data) exports.MULTIcore:Notify(data) end

-- ------------------------------------------------------------
-- player data: the server sends it (redemrp:receivePlayerData); between
-- sends, money, job and metadata follow MULTIcore's own player data
-- ------------------------------------------------------------

AddEventHandler('redemrp:receivePlayerData', function(data)
    if type(data) == 'table' then RedEM.PlayerData = data end
end)
RegisterNetEvent('redemrp:receivePlayerData')

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(d)
    if type(d) ~= 'table' or not RedEM.PlayerData.isLoggedIn then return end
    local pd = RedEM.PlayerData
    pd.money = d.money and d.money.cash or pd.money
    pd.bankmoney = d.money and d.money.bank or pd.bankmoney
    if d.job then
        pd.job = d.job.name
        pd.jobgrade = d.job.grade and tonumber(d.job.grade.level) or 0
    end
    if d.gang then
        pd.gang = d.gang.name
        pd.ganggrade = d.gang.grade and tonumber(d.gang.grade.level) or 0
    end
    if d.charinfo then
        pd.firstname, pd.lastname = d.charinfo.firstname, d.charinfo.lastname
        pd.charname = ('%s %s'):format(pd.firstname or '', pd.lastname or '')
    end
    pd.metadata = d.metadata or pd.metadata
    TriggerEvent('redemrp:receivePlayerData', pd)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    RedEM.PlayerData = { isLoggedIn = false }
end)

-- cash changes, for HUD scripts written for RedEM:RP
RegisterNetEvent('RSGCore:Client:OnMoneyChange', function(kind, amount, op)
    if kind ~= 'cash' then return end
    if op == 'add' then TriggerEvent('redem:addMoney', amount)
    elseif op == 'remove' then TriggerEvent('redem:removeMoney', amount) end
    SetTimeout(250, function()
        TriggerEvent('redem:activateMoney', RedEM.PlayerData.money or 0)
    end)
end)

function RedEM.GetPlayerData() return RedEM.PlayerData end

-- ------------------------------------------------------------
-- callbacks
-- ------------------------------------------------------------

local waiting, nextId = {}, 0

--- RedEM.TriggerCallback(name, function(...) end, ...)
function RedEM.TriggerCallback(name, cb, ...)
    nextId = nextId + 1
    waiting[nextId] = cb
    TriggerServerEvent('MULTIcore:redem:cb', name, nextId, ...)
end

RegisterNetEvent('MULTIcore:redem:cbReply', function(reqId, ...)
    local cb = waiting[reqId]
    waiting[reqId] = nil
    if cb then cb(...) end
end)

local clientCallbacks = {}

--- RedEM.CreateClientCallback(name, function(cb, ...) end)
function RedEM.CreateClientCallback(name, fn)
    if type(name) == 'string' and fn then clientCallbacks[name] = fn end
end

RegisterNetEvent('MULTIcore:redem:ccb', function(name, reqId, ...)
    local fn = clientCallbacks[name]
    if not fn then return end
    fn(function(...) TriggerServerEvent('MULTIcore:redem:ccbReply', reqId, ...) end, ...)
end)

-- ------------------------------------------------------------
-- notifications: every RedEM:RP style is drawn by MULTIcore
-- ------------------------------------------------------------

local function left(title, text, _dict, _icon, ms) notify({ title = title, text = text, duration = tonumber(ms) }) end
local function tip(text, ms) notify({ text = text, duration = tonumber(ms), style = 'tip' }) end
local function top(title, sub, ms) notify({ title = title, text = sub, duration = tonumber(ms), style = 'banner' }) end
local function objective(text, ms) notify({ text = text, duration = tonumber(ms), style = 'objective' }) end

RedEM.Functions.NotifyLeft = left
RedEM.Functions.NotifyRight = tip
RedEM.Functions.NotifyTip = tip
RedEM.NotifyLeft = left
RedEM.NotifyRight = tip

local events = {
    ['redem_roleplay:NotifyLeft'] = left,
    ['redem_roleplay:NotifyRight'] = tip,
    ['redem_roleplay:Tip'] = tip,
    ['redem_roleplay:NotifyTop'] = function(text, _town, ms) top(text, nil, ms) end,
    ['redem_roleplay:ShowSimpleRightText'] = tip,
    ['redem_roleplay:ShowObjective'] = objective,
    ['redem_roleplay:ShowTopNotification'] = top,
    ['redem_roleplay:ShowAdvancedRightNotification'] = function(text, _d, _i, _c, ms) tip(text, ms) end,
    ['redem_roleplay:ShowBasicTopNotification'] = function(text, ms) top(text, nil, ms) end,
    ['redem_roleplay:ShowSimpleCenterText'] = objective,
}
for name, fn in pairs(events) do RegisterNetEvent(name, fn) end

-- ------------------------------------------------------------
-- exports['redem_roleplay']:...
-- ------------------------------------------------------------

MULTI.ExportAs('redem_roleplay', 'RedEM', function() return RedEM end)
MULTI.ExportAs('redem_roleplay', 'GetPlayerData', function() return RedEM.PlayerData end)
MULTI.ExportAs('redem_roleplay', 'ShowTooltip', tip)
MULTI.ExportAs('redem_roleplay', 'ShowAdvancedNotification', left)
MULTI.ExportAs('redem_roleplay', 'ShowSimpleRightText', tip)
MULTI.ExportAs('redem_roleplay', 'ShowObjective', objective)
MULTI.ExportAs('redem_roleplay', 'ShowTopNotification', top)
MULTI.ExportAs('redem_roleplay', 'ShowBasicTopNotification', function(text, ms) top(text, nil, ms) end)
MULTI.ExportAs('redem_roleplay', 'ShowSimpleCenterText', objective)
MULTI.ExportAs('redem_roleplay', 'ShowAdvancedRightNotification', function(text, _d, _i, _c, ms) tip(text, ms) end)
