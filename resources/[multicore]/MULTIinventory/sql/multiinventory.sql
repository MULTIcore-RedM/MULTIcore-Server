-- MULTIinventory tables. MULTIinventory also runs these itself on start (CREATE TABLE IF NOT EXISTS),
-- so importing this file is optional.
-- The player's satchel lives in `players`.`inventory` (RSG's column, made by MULTIcore).

-- stashes, gloveboxes, trunks, custom inventories (same shape as RSG v2's `inventories`)
CREATE TABLE IF NOT EXISTS `inventories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(255) NOT NULL,
  `items` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- small key / value store (the weapon id counter: k = 'weapon_id')
CREATE TABLE IF NOT EXISTS `multiinventory_kv` (
  `k` VARCHAR(64) NOT NULL,
  `v` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
