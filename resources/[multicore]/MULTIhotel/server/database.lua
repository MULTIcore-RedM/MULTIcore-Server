-- ============================================================
-- MULTIhotel :: database
-- Makes multi_hotel_rooms and multi_hotel_guests on start when they
-- are missing. sql/multihotel.sql holds the same for those who import
-- by hand.
-- ============================================================

DB = { ready = false }

local CREATE_ROOMS = [[
CREATE TABLE IF NOT EXISTS `multi_hotel_rooms` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `roomid` INT(11) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `fullname` VARCHAR(255) NOT NULL DEFAULT '',
  `location` VARCHAR(30) NOT NULL,
  `credit` INT(11) NOT NULL DEFAULT 0,
  `rented_at` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_roomid` (`roomid`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

local CREATE_GUESTS = [[
CREATE TABLE IF NOT EXISTS `multi_hotel_guests` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `roomid` INT(11) NOT NULL,
  `owner_citizenid` VARCHAR(64) NOT NULL,
  `guest_citizenid` VARCHAR(64) NOT NULL,
  `guest_name` VARCHAR(255) NOT NULL DEFAULT '',
  `added_at` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_roomid` (`roomid`),
  KEY `idx_guest` (`guest_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await(CREATE_ROOMS)
        MySQL.query.await(CREATE_GUESTS)
    end)
    if not ok then
        print('^1[MULTIhotel] could not make the hotel tables: ' .. tostring(err) .. '^7')
        return
    end
    DB.ready = true
end)
