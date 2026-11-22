-- ============================================================
-- MULTIhouses :: database
-- Makes multi_houses, multi_housekeys and multi_housedoors on start when
-- they are missing, fills multi_houses with the 51 houses and their prices
-- and multi_housedoors with the door hashes, but only while a table is
-- empty. Doors in Config.HouseDoors that have no row yet get one.
-- sql/multihouses.sql holds the same for those who import by hand.
-- ============================================================

DB = { ready = false }

local CREATE_HOUSES = [[
CREATE TABLE IF NOT EXISTS `multi_houses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `houseid` VARCHAR(20) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
  `fullname` VARCHAR(255) NOT NULL DEFAULT '',
  `owned` TINYINT(1) NOT NULL DEFAULT 0,
  `price` INT(11) NOT NULL DEFAULT 0,
  `credit` INT(11) NOT NULL DEFAULT 0,
  `balance` INT(11) NOT NULL DEFAULT 0,
  `bought_at` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_houseid` (`houseid`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local CREATE_KEYS = [[
CREATE TABLE IF NOT EXISTS `multi_housekeys` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `houseid` VARCHAR(20) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `guest` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_house` (`houseid`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local CREATE_DOORS = [[
CREATE TABLE IF NOT EXISTS `multi_housedoors` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `doorid` VARCHAR(11) NOT NULL,
  `doorstate` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_doorid` (`doorid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

-- houseid, price
local SEED_HOUSES = {
    { 'house1', 3000 }, { 'house2', 4000 }, { 'house3', 2000 }, { 'house4', 4000 }, { 'house5', 3000 },
    { 'house6', 2000 }, { 'house7', 2000 }, { 'house8', 4000 }, { 'house9', 1000 }, { 'house10', 4000 },
    { 'house11', 4000 }, { 'house12', 4000 }, { 'house13', 5000 }, { 'house14', 4000 }, { 'house15', 2000 },
    { 'house16', 3000 }, { 'house17', 3000 }, { 'house18', 4000 }, { 'house19', 500 }, { 'house20', 3000 },
    { 'house21', 2500 }, { 'house22', 2000 }, { 'house23', 2500 }, { 'house24', 1000 }, { 'house25', 2000 },
    { 'house26', 3500 }, { 'house27', 1250 }, { 'house28', 1500 }, { 'house29', 1000 }, { 'house30', 4000 },
    { 'house31', 1500 }, { 'house32', 1500 }, { 'house33', 1250 }, { 'house34', 1000 }, { 'house35', 1000 },
    { 'house36', 2000 }, { 'house37', 3000 }, { 'house38', 750 }, { 'house39', 2000 }, { 'house40', 1300 },
    { 'house41', 0 }, { 'house42', 2500 }, { 'house43', 2500 }, { 'house44', 3000 }, { 'house45', 10000 },
    { 'house46', 2000 }, { 'house47', 2000 }, { 'house48', 2000 }, { 'house49', 2000 }, { 'house50', 2000 },
    { 'house51', 2000 },
}

local SEED_DOORS = {
    '3598523785', '2031215067', '1189146288', '906448125', '2821676992', '1510914117', '3549587335', '3000692149',
    '1928053488', '772977516', '527767089', '3468185317', '2779142555', '1239033969', '1597362984', '1299456376',
    '2933656395', '3238637478', '3544613794', '1485561723', '1511858696', '1282705079', '2238665296', '2080980868',
    '2700347737', '2544301759', '3720952508', '350169319', '984852093', '3473362722', '686097120', '3107660458',
    '3419719645', '3945582303', '862008394', '1661737397', '1574473390', '3731688048', '344028824', '2652873387',
    '2061942857', '3702071668', '1934463007', '2183007198', '4288310487', '872775928', '2385374047', '2051127971',
    '3167436574', '1195519038', '2212914984', '562830153', '663425326', '1171581101', '52014802', '4164042403',
    '2047072501', '2715667864', '1263476860', '1894337720', '120764251', '943176298', '2971757040', '1973911195',
    '784290387', '843137708', '4275653891', '1431398235', '896012811', '2813949612', '868379185', '640077562',
    '3045682143', '1915887592', '3324299212', '1180868565', '1535511805', '2395304827', '1762076266', '2689340659',
    '1606546482', '818583340', '2310818050', '362914435', '3108731901', '3929468747', '4123766266', '417362979',
}

local function count(tbl)
    return tonumber(MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(tbl))) or 0
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end

    MySQL.query.await(CREATE_HOUSES)
    MySQL.query.await(CREATE_KEYS)
    MySQL.query.await(CREATE_DOORS)

    if count('multi_houses') == 0 then
        for _, h in ipairs(SEED_HOUSES) do
            MySQL.insert.await('INSERT INTO `multi_houses` (`houseid`, `price`) VALUES (?, ?)', { h[1], h[2] })
        end
        print(('[MULTIhouses] %d houses added to multi_houses'):format(#SEED_HOUSES))
    end

    if count('multi_housedoors') == 0 then
        for _, id in ipairs(SEED_DOORS) do
            MySQL.insert.await('INSERT INTO `multi_housedoors` (`doorid`, `doorstate`) VALUES (?, 1)', { id })
        end
        print(('[MULTIhouses] %d doors added to multi_housedoors'):format(#SEED_DOORS))
    end

    -- a house or door added to config.lua later gets its row
    for _, h in ipairs(Config.Houses) do
        MySQL.insert.await('INSERT IGNORE INTO `multi_houses` (`houseid`, `price`) VALUES (?, 0)', { h.houseid })
    end
    for _, d in ipairs(Config.HouseDoors) do
        MySQL.insert.await('INSERT IGNORE INTO `multi_housedoors` (`doorid`, `doorstate`) VALUES (?, 1)', { tostring(d.doorid) })
    end

    DB.ready = true
    TriggerEvent('MULTIhouses:ready')
end)
