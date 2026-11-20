-- ============================================================
-- MULTItelegram :: rsg-telegram face (client)
-- Client events of rsg-telegram 2.1.1 that other scripts trigger
-- (rsg-prison, rsg-radialmenu and RINGOradialmenu use these),
-- opened on MULTItelegram's own page. Each works as a net event
-- and as a local TriggerEvent.
-- GPL v3.
-- ============================================================

local function open(mode) return function() MTC.Open(mode) end end

RegisterNetEvent('rsg-telegram:client:OpenTelegram', open('inbox'))            -- /telegram
RegisterNetEvent('rsg-telegram:client:ReadMessages', open('inbox'))            -- rsg-prison
RegisterNetEvent('rsg-telegram:client:WriteMessagePostOffice', open('compose')) -- rsg-prison
RegisterNetEvent('rsg-telegram:client:WriteMessage', open('compose'))          -- bird post item (sending still needs an office)
RegisterNetEvent('rsg-telegram:client:OpenAddressbook', open('contacts'))      -- rsg-radialmenu, RINGOradialmenu
