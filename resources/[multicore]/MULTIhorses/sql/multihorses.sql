-- MULTIhorses tables. They are made on start (CREATE TABLE IF NOT EXISTS); import this only if you want to.
-- player_horses has rsg-horses' shape (RSG v2 framework, GPL v3, installation/setup.sql).
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
  `age_seconds` INT(11) NOT NULL DEFAULT 0,
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

-- MULTIhorses' own extras per horse (health / stamina cores, fallen, tack)
CREATE TABLE IF NOT EXISTS `multihorses_state` (
  `horseid` VARCHAR(6) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `health` TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `stamina` TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `injured` TINYINT(1) NOT NULL DEFAULT 0,
  `tack` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`horseid`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
