-- VORP-shaped tables that VORP scripts query directly (docs/COMPAT_SURVEY.md gaps 5 and 6).
-- Created on start by server/multi/schema.lua; this file is also safe to import by hand.
-- Column names follow VORP's public database shape and the queries scripts run against it.
-- MULTIcore's own data stays in `players`; these are kept in step by server/multi/compat_characters.lua.

-- One row per character. charidentifier = players.id (what VORP scripts know as charIdentifier).
-- MULTIcore writes the row on create, login, save and logout. Script writes to money, gold, rol,
-- job, jobgrade and joblabel are picked up and applied to the character (see compat_characters.lua).
-- `citizenid` is MULTIcore's own extra column (links the row to players.citizenid).
CREATE TABLE IF NOT EXISTS `characters` (
  `charidentifier` INT NOT NULL,
  `identifier` VARCHAR(50) NOT NULL DEFAULT '',
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `steamname` VARCHAR(255) NOT NULL DEFAULT '',
  `group` VARCHAR(50) DEFAULT 'user',
  `money` DOUBLE(11,2) DEFAULT 0.00,
  `gold` DOUBLE(11,2) DEFAULT 0.00,
  `rol` DOUBLE(11,2) DEFAULT 0.00,
  `xp` INT DEFAULT 0,
  `hours` FLOAT NOT NULL DEFAULT 0,
  `LastLogin` DATE DEFAULT NULL,
  `job` VARCHAR(50) DEFAULT 'unemployed',
  `jobgrade` INT DEFAULT 0,
  `joblabel` VARCHAR(255) DEFAULT 'Unemployed',
  `firstname` VARCHAR(50) DEFAULT ' ',
  `lastname` VARCHAR(50) DEFAULT ' ',
  `character_desc` MEDIUMTEXT DEFAULT NULL,
  `gender` VARCHAR(50) DEFAULT NULL,
  `age` INT DEFAULT 0,
  `nickname` VARCHAR(50) DEFAULT NULL,
  `skinPlayer` LONGTEXT DEFAULT NULL,
  `compPlayer` LONGTEXT DEFAULT NULL,
  `compTints` LONGTEXT DEFAULT NULL,
  `coords` LONGTEXT DEFAULT NULL,
  `isdead` TINYINT(1) DEFAULT 0,
  `status` VARCHAR(255) DEFAULT '{}',
  PRIMARY KEY (`charidentifier`),
  KEY `identifier` (`identifier`),
  KEY `citizenid` (`citizenid`),
  KEY `job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- What MULTIcore last wrote to `characters` (money and job columns). A difference between this and
-- `characters` is a change a script made with SQL; MULTIcore applies it to the character.
CREATE TABLE IF NOT EXISTS `multicore_vorp_sync` (
  `charidentifier` INT NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `money` DOUBLE(11,2) DEFAULT 0.00,
  `gold` DOUBLE(11,2) DEFAULT 0.00,
  `rol` DOUBLE(11,2) DEFAULT 0.00,
  `job` VARCHAR(50) DEFAULT NULL,
  `jobgrade` INT DEFAULT 0,
  `joblabel` VARCHAR(255) DEFAULT NULL,
  `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`charidentifier`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- VORP inventory tables. Created EMPTY so scripts that move custom-inventory contents with SQL
-- (UPDATE character_inventories SET inventory_type ..., UPDATE loadout SET curr_inv ..., COUNT(*))
-- run without errors. Item and weapon contents live in MULTIinventory, not here, so these
-- queries find and move nothing.
CREATE TABLE IF NOT EXISTS `character_inventories` (
  `character_id` INT DEFAULT NULL,
  `inventory_type` VARCHAR(100) NOT NULL DEFAULT 'default',
  `item_crafted_id` INT NOT NULL DEFAULT 0,
  `amount` INT DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `character_id` (`character_id`),
  KEY `inventory_type` (`inventory_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `loadout` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(50) NOT NULL DEFAULT '',
  `charidentifier` INT DEFAULT NULL,
  `name` VARCHAR(50) DEFAULT NULL,
  `ammo` VARCHAR(255) NOT NULL DEFAULT '{}',
  `components` VARCHAR(255) NOT NULL DEFAULT '[]',
  `comps` LONGTEXT DEFAULT NULL,
  `dirtlevel` DOUBLE DEFAULT 0,
  `mudlevel` DOUBLE DEFAULT 0,
  `conditionlevel` DOUBLE DEFAULT 0,
  `rustlevel` DOUBLE DEFAULT 0,
  `used` TINYINT(1) DEFAULT 0,
  `used2` TINYINT(1) DEFAULT 0,
  `dropped` INT NOT NULL DEFAULT 0,
  `label` VARCHAR(50) DEFAULT NULL,
  `curr_inv` VARCHAR(100) NOT NULL DEFAULT 'default',
  `serial_number` VARCHAR(50) DEFAULT NULL,
  `custom_label` VARCHAR(50) DEFAULT NULL,
  `custom_desc` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `charidentifier` (`charidentifier`),
  KEY `curr_inv` (`curr_inv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
