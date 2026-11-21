-- MULTIhorses: the player_horses table.
-- The script makes it on start and adds any missing column by itself
-- (server/database.lua); import this only if you want to do it by hand.

CREATE TABLE IF NOT EXISTS `player_horses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `stable` VARCHAR(50) NOT NULL DEFAULT 'valentine',
  `citizenid` VARCHAR(50) NOT NULL,
  `horseid` VARCHAR(6) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `horse` VARCHAR(100) NOT NULL,
  `gender` VARCHAR(10) NOT NULL DEFAULT 'male',
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `born` INT(11) NOT NULL DEFAULT 0,
  `components` LONGTEXT DEFAULT NULL,
  `coat` LONGTEXT DEFAULT NULL,
  `horsexp` INT(11) NOT NULL DEFAULT 0,
  `dirt` INT(11) NOT NULL DEFAULT 0,
  `age_seconds` INT(11) NOT NULL DEFAULT 604800,
  `pregnant_until` INT(11) DEFAULT NULL,
  `last_bred` INT(11) DEFAULT NULL,
  `stored_weapon` VARCHAR(100) DEFAULT NULL,
  `stored_weapon_name` VARCHAR(100) DEFAULT NULL,
  `stored_weapon_data` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_horseid` (`horseid`),
  KEY `idx_active` (`citizenid`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- An older player_horses (the earlier MULTIhorses, older stable scripts):
-- add what is missing. MariaDB syntax; on MySQL leave out IF NOT EXISTS
-- and run only the lines for columns you lack (the script does this itself).
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `gender` VARCHAR(10) NOT NULL DEFAULT 'male';
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `active` TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `born` INT(11) NOT NULL DEFAULT 0;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `components` LONGTEXT DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `coat` LONGTEXT DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `horsexp` INT(11) NOT NULL DEFAULT 0;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `dirt` INT(11) NOT NULL DEFAULT 0;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `age_seconds` INT(11) NOT NULL DEFAULT 604800;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `pregnant_until` INT(11) DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `last_bred` INT(11) DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `stored_weapon` VARCHAR(100) DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `stored_weapon_name` VARCHAR(100) DEFAULT NULL;
ALTER TABLE `player_horses` ADD COLUMN IF NOT EXISTS `stored_weapon_data` LONGTEXT DEFAULT NULL;

-- rows other scripts insert (starter horses) start grown up, not as foals
ALTER TABLE `player_horses` ALTER COLUMN `age_seconds` SET DEFAULT 604800;

-- The earlier MULTIhorses also kept `multihorses_state` (health/stamina cores,
-- hurt flag, saddle and blanket). On the first start the script turns the
-- saddle and blanket into customization pieces, gives every carried-over horse
-- saddlebags and makes it grown up. The table is left in place and no longer used;
-- drop it once you are happy:  DROP TABLE IF EXISTS `multihorses_state`;
