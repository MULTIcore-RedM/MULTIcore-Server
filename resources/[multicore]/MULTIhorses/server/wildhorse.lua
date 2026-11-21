-- ============================================================
-- MULTIhorses :: wild horses (server)
-- Rewards for a sold wild horse are worked out here from the model and
-- config/wildhorse.lua, never taken from the client. Saved wild horses go
-- into player_horses like any other horse (lowercase model and gender).
-- ============================================================
local Core = exports['rsg-core']:GetCoreObject()

-- reward per model hash, from config/wildhorse.lua
local wildHorseRewards = {}
for _, horseCfg in pairs(Config.WildHorse.Horse or {}) do
    if horseCfg.model then
        wildHorseRewards[horseCfg.model] = { money = tonumber(horseCfg.rewardmoney) or 0, item = horseCfg.rewarditem }
    end
end

local wildHorseSellCooldowns = {} -- citizenid -> os.time() of the last sale

RegisterNetEvent('MULTIhorses:wild:server:reward', function(modelHash)
    local src = source
    if Config.WildHorse.Enabled == false then return end
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local citizenid = Player.PlayerData.citizenid

    local reward = wildHorseRewards[tonumber(modelHash) or modelHash]
    if not reward then
        SendDiscordLog('security', 'Rejected Wild Horse Reward', 'Player asked for a wild horse reward with an unknown model.', WebhookColors.danger, {
            { name = 'Model', value = tostring(modelHash), inline = true },
        }, src)
        return
    end

    -- the player must stand at a horse seller
    local ped = GetPlayerPed(src)
    local pos = ped and ped ~= 0 and GetEntityCoords(ped)
    local atSeller = false
    for _, v in pairs(Config.WildHorse.SellWildHorseLocations or {}) do
        if pos and #(pos - v.coords) < 15.0 then atSeller = true break end
    end
    if not atSeller then
        SendDiscordLog('security', 'Wild Horse Sale Away From Seller', 'Player asked for a wild horse reward away from every horse seller.', WebhookColors.warning, nil, src)
        return
    end

    -- server-side cooldown, whatever the client's own timer does
    if Config.WildHorse.EnableCooldown then
        local cooldownSecs = tonumber(Config.WildHorse.Cooldown) or 0
        local lastSold = wildHorseSellCooldowns[citizenid]
        if lastSold and (os.time() - lastSold) < cooldownSecs then
            SendDiscordLog('security', 'Wild Horse Sell Cooldown Hit', 'Player tried to sell a wild horse again before the cooldown ran out.', WebhookColors.warning, {
                { name = 'Seconds Remaining', value = tostring(cooldownSecs - (os.time() - lastSold)), inline = true },
            }, src)
            return
        end
    end

    local money = math.floor(math.max(0, reward.money) * (tonumber(Config.WildHorse.SaleMultiplier) or 1))
    wildHorseSellCooldowns[citizenid] = os.time()

    if money > 0 then Player.Functions.AddMoney(Config.WildHorse.PaymentType, money) end
    if reward.item and reward.item ~= '' and Player.Functions.AddItem(reward.item, 1) then
        ItemBox(src, reward.item, 1, 'add')
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = _L('wh_title'),
        description = _L('wh_success_sold_for', money),
        type = 'success',
        duration = 3000
    })

    ServerLog('MULTIhorses', _L('wh_title'), 'yellow', firstname .. ' ' .. lastname .. ': ' .. _L('wh_success_sold_for', money))

    SendDiscordLog('economy', 'Wild Horse Sold', firstname .. ' ' .. lastname .. ' sold a tamed wild horse.', WebhookColors.success, {
        { name = 'Reward', value = '$' .. tostring(money), inline = true },
        { name = 'Item', value = tostring(reward.item), inline = true },
    }, src)
end)

-- horse model names by hash
local horseNames = {
    "a_c_horse_nokota_whiteroan",
    "a_c_donkey_01",
    "A_C_Horse_AmericanPaint_Greyovero",
    "A_C_Horse_AmericanPaint_Overo",
    "A_C_Horse_AmericanPaint_SplashedWhite",
    "A_C_Horse_AmericanPaint_Tobiano",
    "A_C_Horse_AmericanStandardbred_Black",
    "A_C_Horse_AmericanStandardbred_Buckskin",
    "A_C_Horse_AmericanStandardbred_PalominoDapple",
    "A_C_Horse_AmericanStandardbred_SilverTailBuckskin",
    "A_C_Horse_AmericanStandardbred_LightBuckskin",
    "A_C_Horse_Andalusian_DarkBay",
    "A_C_Horse_Andalusian_Perlino",
    "A_C_Horse_Andalusian_RoseGray",
    "A_C_Horse_Appaloosa_BlackSnowflake",
    "A_C_Horse_Appaloosa_Blanket",
    "A_C_Horse_Appaloosa_BrownLeopard",
    "A_C_Horse_Appaloosa_FewSpotted_PC",
    "A_C_Horse_Appaloosa_Leopard",
    "A_C_Horse_Appaloosa_LeopardBlanket",
    "A_C_Horse_Arabian_Black",
    "A_C_Horse_Arabian_Grey",
    "A_C_Horse_Arabian_RedChestnut",
    "A_C_Horse_Arabian_RedChestnut_PC",
    "A_C_Horse_Arabian_RoseGreyBay",
    "A_C_Horse_Arabian_WarpedBrindle_PC",
    "A_C_Horse_Arabian_White",
    "A_C_Horse_Ardennes_BayRoan",
    "A_C_Horse_Ardennes_IronGreyRoan",
    "A_C_Horse_Ardennes_StrawberryRoan",
    "A_C_Horse_Belgian_BlondChestnut",
    "A_C_Horse_Belgian_MealyChestnut",
    "A_C_Horse_Breton_GrulloDun",
    "A_C_Horse_Breton_MealyDappleBay",
    "A_C_Horse_Breton_RedRoan",
    "A_C_Horse_Breton_SealBrown",
    "A_C_Horse_Breton_Sorrel",
    "A_C_Horse_Breton_SteelGrey",
    "A_C_Horse_Breton_Bayblonde",
    "A_C_Horse_Breton_BlackChestnut",
    "A_C_Horse_Breton_Liverchestnut",
    "A_C_Horse_Buell_WarVets",
    "A_C_Horse_Criollo_BayBrindle",
    "A_C_Horse_Criollo_BayFrameOvero",
    "A_C_Horse_Criollo_BlueRoanOvero",
    "A_C_Horse_Criollo_Dun",
    "A_C_Horse_Criollo_MarbleSabino",
    "A_C_Horse_Criollo_SorrelOvero",
    "A_C_Horse_Criollo_BayRoan",
    "A_C_Horse_Criollo_Buckskin",
    "A_C_Horse_Criollo_GrullaDun",
    "A_C_Horse_DutchWarmblood_ChocolateRoan",
    "A_C_Horse_DutchWarmblood_SealBrown",
    "A_C_Horse_DutchWarmblood_SootyBuckskin",
    "A_C_Horse_Gang_Bill",
    "A_C_Horse_Gang_Charles",
    "A_C_Horse_Gang_Charles_EndlessSummer",
    "A_C_Horse_Gang_Dutch",
    "A_C_Horse_Gang_Hosea",
    "A_C_Horse_Gang_Javier",
    "A_C_Horse_Gang_John",
    "A_C_Horse_Gang_Karen",
    "A_C_Horse_Gang_Kieran",
    "A_C_Horse_Gang_Lenny",
    "A_C_Horse_Gang_Micah",
    "A_C_Horse_Gang_Sadie",
    "A_C_Horse_Gang_Sadie_EndlessSummer",
    "A_C_Horse_Gang_Sean",
    "A_C_Horse_Gang_Trelawney",
    "A_C_Horse_Gang_Uncle",
    "A_C_Horse_Gang_Uncle_EndlessSummer",
    "A_C_Horse_GypsyCob_Skewbald",
    "A_C_Horse_GypsyCob_SplashedPiebald",
    "A_C_Horse_GypsyCob_WhiteBlagdon",
    "A_C_Horse_GypsyCob_PiebaldRosamillo",
    "A_C_Horse_GypsyCob_PalominoBlagdon",
    "A_C_Horse_GypsyCob_DarkBay",
    "A_C_Horse_HungarianHalfbred_DarkDappleGrey",
    "A_C_Horse_HungarianHalfbred_LiverChestnut",
    "A_C_Horse_HungarianHalfbred_FlaxenChestnut",
    "A_C_Horse_HungarianHalfbred_PiebaldTobiano",
    "A_C_Horse_John_EndlessSummer",
    "A_C_Horse_KentuckySaddle_Black",
    "A_C_Horse_KentuckySaddle_ButterMilkBuckskin_PC",
    "A_C_Horse_KentuckySaddle_ChestnutPinto",
    "A_C_Horse_KentuckySaddle_Grey",
    "A_C_Horse_KentuckySaddle_SilverBay",
    "A_C_Horse_Kladruber_Black",
    "A_C_Horse_Kladruber_Cremello",
    "A_C_Horse_Kladruber_DappleRoseGrey",
    "A_C_Horse_Kladruber_Grey",
    "A_C_Horse_Kladruber_Silver",
    "A_C_Horse_Kladruber_White",
    "A_C_Horse_Kladruber_BayRoan",
    "A_C_Horse_Kladruber_Lightbuckskin",
    "A_C_Horse_Kladruber_SilverDapple",
    "A_C_Horse_MissouriFoxTrotter_AmberChampagne",
    "A_C_Horse_MissouriFoxTrotter_BuckskinBrindle",
    "A_C_Horse_MissouriFoxTrotter_DappleGrey",
    "A_C_Horse_MissouriFoxTrotter_SableChampagne",
    "A_C_Horse_MissouriFoxTrotter_SilverDapplePinto",
    "A_C_Horse_Morgan_Bay",
    "A_C_Horse_Morgan_BayRoan",
    "A_C_Horse_Morgan_FlaxenChestnut",
    "A_C_Horse_Morgan_LiverChestnut_PC",
    "A_C_Horse_Morgan_Palomino",
    "A_C_Horse_MP_Mangy_Backup",
    "A_C_Horse_MurfreeBrood_Mange_01",
    "A_C_Horse_MurfreeBrood_Mange_02",
    "A_C_Horse_MurfreeBrood_Mange_03",
    "A_C_Horse_Mustang_GoldenDun",
    "A_C_Horse_Mustang_GrulloDun",
    "A_C_Horse_Mustang_RedDunOvero",
    "A_C_Horse_Mustang_TigerStripedBay",
    "A_C_Horse_Mustang_WildBay",
    "A_C_Horse_Mustang_BuckskinBrindle",
    "A_C_Horse_Mustang_ChestnutDunOvero",
    "A_C_Horse_Mustang_RedDun",
    "A_C_Horse_Nokota_BlueRoan",
    "A_C_Horse_Nokota_ReverseDappleRoan",
    "A_C_Horse_NorfolkRoadster_PiebaldRoan",
    "A_C_Horse_NorfolkRoadster_SpeckledGrey",
    "A_C_Horse_NorfolkRoadster_SpottedTricolor",
    "A_C_Horse_NorfolkRoadster_Black",
    "A_C_Horse_NorfolkRoadster_DappleBuckskin",
    "A_C_Horse_NorfolkRoadster_RoseGrey",
    "A_C_Horse_Shire_DarkBay",
    "A_C_Horse_Shire_LightGrey",
    "A_C_Horse_Shire_RavenBlack",
    "A_C_Horse_SuffolkPunch_RedChestnut",
    "A_C_Horse_SuffolkPunch_Sorrel",
    "A_C_Horse_TennesseeWalker_BlackRabicano",
    "A_C_Horse_TennesseeWalker_Chestnut",
    "A_C_Horse_TennesseeWalker_DappleBay",
    "A_C_Horse_TennesseeWalker_FlaxenRoan",
    "A_C_Horse_TennesseeWalker_GoldPalomino_PC",
    "A_C_Horse_TennesseeWalker_MahoganyBay",
    "A_C_Horse_TennesseeWalker_RedRoan",
    "A_C_Horse_Thoroughbred_BlackChestnut",
    "A_C_Horse_Thoroughbred_BloodBay",
    "A_C_Horse_Thoroughbred_Brindle",
    "A_C_Horse_Thoroughbred_DappleGrey",
    "A_C_Horse_Thoroughbred_ReverseDappleBlack",
    "A_C_Horse_Turkoman_DarkBay",
    "A_C_Horse_Turkoman_Gold",
    "A_C_Horse_Turkoman_Silver",
    "A_C_Horse_Turkoman_Chestnut",
    "A_C_Horse_Turkoman_Grey",
    "A_C_Horse_Turkoman_Perlino",
    "A_C_Horse_Winter02_01",
    "A_C_HorseMule_01",
    "A_C_HorseMulePainted_01",
    "P_C_Horse_01",
    "A_C_Horse_EagleFlies",
    -- PC Variants
    "A_C_Horse_Americanpaint_Tobiano_PC",
    "A_C_Horse_Andalusian_DarkBay_PC",
    "A_C_Horse_Andalusian_Perlino_PC",
    "A_C_Horse_Andalusian_RoseGray_PC",
    "A_C_Horse_Appaloosa_BlackSnowflake_PC",
    "A_C_Horse_Appaloosa_Blanket_PC",
    "A_C_Horse_Appaloosa_BrownLeopard_PC",
    "A_C_Horse_Appaloosa_Leopard_PC",
    "A_C_Horse_Appaloosa_LeopardBlanket_PC",
    "A_C_Horse_Arabian_Black_PC",
    "A_C_Horse_Arabian_Grey_PC",
    "A_C_Horse_Arabian_RoseGreyBay_PC",
    "A_C_Horse_Arabian_White_PC",
    "A_C_Horse_Ardennes_BayRoan_PC",
    "A_C_Horse_Ardennes_IronGreyRoan_PC",
    "A_C_Horse_Ardennes_StrawberryRoan_PC",
    "A_C_Horse_Belgian_BlondChestnut_PC",
    "A_C_Horse_DutchWarmblood_ChocolateRoan_PC",
    "A_C_Horse_DutchWarmblood_SealBrown_PC",
    "A_C_Horse_DutchWarmblood_SootyBuckskin_PC",
    "A_C_Horse_HungarianHalfbred_DarkDappleGrey_PC",
    "A_C_Horse_HungarianHalfbred_FlaxenChestnut_PC",
    "A_C_Horse_KentuckySaddle_ChestnutPinto_PC",
    "A_C_Horse_KentuckySaddle_Grey_PC",
    "A_C_Horse_KentuckySaddle_SilverBay_PC",
    "A_C_Horse_MissouriFoxTrotter_AmberChampagne_PC",
    "A_C_Horse_MissouriFoxTrotter_DappleGrey_PC",
    "A_C_Horse_MissouriFoxTrotter_SableChampagne_PC",
    "A_C_Horse_MissouriFoxTrotter_SilverDapplePinto_PC",
    "A_C_Horse_Morgan_Bay_PC",
    "A_C_Horse_Morgan_BayRoan_PC",
    "A_C_Horse_Morgan_FlaxenChestnut_PC",
    "A_C_Horse_Morgan_Palomino_PC",
    "A_C_Horse_Mustang_GoldenDun_PC",
    "A_C_Horse_Mustang_GrulloDun_PC",
    "A_C_Horse_Mustang_TigerStripedBay_PC",
    "A_C_Horse_Mustang_WildBay_PC",
    "A_C_Horse_Nokota_BlueRoan_PC",
    "A_C_Horse_Nokota_ReverseDappleRoan_PC",
    "A_C_Horse_Nokota_WhiteRoan_PC",
    "A_C_Horse_Shire_DarkBay_PC",
    "A_C_Horse_Shire_LightGrey_PC",
    "A_C_Horse_Shire_RavenBlack_PC",
    "A_C_Horse_SuffolkPunch_RedChestnut_PC",
    "A_C_Horse_SuffolkPunch_Sorrel_PC",
    "A_C_Horse_TennesseeWalker_BlackRabicano_PC",
    "A_C_Horse_TennesseeWalker_Chestnut_PC",
    "A_C_Horse_TennesseeWalker_DappleBay_PC",
    "A_C_Horse_TennesseeWalker_FlaxenRoan_PC",
    "A_C_Horse_TennesseeWalker_MahoganyBay_PC",
    "A_C_Horse_TennesseeWalker_RedRoan_PC",
    "A_C_Horse_Thoroughbred_BlackChestnut_PC",
    "A_C_Horse_Thoroughbred_BloodBay_PC",
    "A_C_Horse_Thoroughbred_Brindle_PC",
    "A_C_Horse_Thoroughbred_DappleGrey_PC",
    "A_C_Horse_Thoroughbred_ReverseDappleBlack_PC",
    "A_C_Horse_Turkoman_DarkBay_PC",
    "A_C_Horse_Turkoman_Gold_PC",
    "A_C_Horse_Turkoman_Silver_PC",
}


local horseModels = {}
for _, name in ipairs(horseNames) do
    horseModels[joaat(name)] = name
end

RegisterNetEvent('MULTIhorses:wild:server:WildHorseStable', function(modelHash, horsename, gender)
    local src = source
    if Config.WildHorse.Enabled == false then return end
    local Player = Core.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    local modelName = horseModels[modelHash]
    if not modelName then
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('wh_title'),
            description = _L('wh_error_invalid_model'),
            type = 'error',
            duration = 5000
        })
        SendDiscordLog('security', 'Wild Horse Stable Rejected - Invalid Model', 'Player tried to stable a wild horse with an unknown model hash.', WebhookColors.warning, {
            { name = 'Model Hash', value = tostring(modelHash), inline = true },
        }, src)
        return
    end

    -- lowercase model (lookups and breed lists use lowercase) and gender ('male' / 'female')
    modelName = string.lower(modelName)
    gender = string.lower(tostring(gender or ''))
    if gender ~= 'male' and gender ~= 'female' then
        gender = 'male'
    end
    if type(horsename) ~= 'string' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('wh_title'),
            description = _L('wh_error_invalid_name'),
            type = 'error',
            duration = 5000
        })
        return
    end
    horsename = string.gsub(horsename, "[^%w%s%-_]", "")
    if #horsename < 1 or #horsename > 30 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('wh_title'),
            description = _L('wh_error_invalid_name'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local horseid = GenerateHorseid()
    local stable = Config.WildHorse.SaveStable or Config.DefaultStable or 'valentine'

    -- born 4 days ago and grown up, so it is not a foal
    local fourDays = 4 * 24 * 60 * 60
    local insertId = MySQL.insert.await([[
        INSERT INTO player_horses
        (stable, citizenid, horseid, name, horse, gender, active, born, components, horsexp, dirt, age_seconds)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { stable, citizenid, horseid, horsename, modelName, gender, 0, os.time() - fourDays, json.encode({}), 0, 0, fourDays })

    if insertId and insertId > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('wh_title'),
            description = _L('wh_save_success', horsename, StableLabel(stable)),
            type = 'success',
            duration = 5000
        })

        TriggerClientEvent('MULTIhorses:wild:client:DeleteWildHorse', src)

        SendDiscordLog('horses', 'Wild Horse Tamed & Stabled', horsename .. ' (' .. modelName .. ') tamed and added to the ' .. stable .. ' stable.', WebhookColors.info, {
            { name = 'Horse Name', value = horsename, inline = true },
            { name = 'Model', value = modelName, inline = true },
            { name = 'Gender', value = gender, inline = true },
        }, src)

        if Config.WildHorse.Debug then
            print('[MULTIhorses] wild horse saved, row ' .. tostring(insertId))
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = _L('wh_title'),
            description = _L('wh_error_save_failed'),
            type = 'error',
            duration = 5000
        })
    end
end)

-- /sethorsewild makes the horse you ride wild again (admins; only with Config.WildHorse.Debug)
if Config.WildHorse.Debug then
    lib.addCommand('sethorsewild', { help = 'MULTIhorses: make the horse you ride a wild horse (testing)', restricted = 'group.admin' }, function(source)
        TriggerClientEvent('MULTIhorses:wild:client:SetHorseAsWild', source)
    end)
end
