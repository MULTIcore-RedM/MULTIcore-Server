-- MULTIhotel makes these tables by itself on start. Import this file only if you prefer to do it by hand.

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
