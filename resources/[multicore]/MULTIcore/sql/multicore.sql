-- MULTIcore's own tables. Created on start; this file is also safe to import by hand.

-- Accounts, in the shape VORP scripts expect (one row per player identifier)
CREATE TABLE IF NOT EXISTS `users` (
  `identifier` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `group` VARCHAR(50) DEFAULT 'user',
  `warnings` INT(11) DEFAULT 0,
  `banned` TINYINT(1) DEFAULT NULL,
  `banneduntil` INT(10) DEFAULT 0,
  `char` INT DEFAULT 5,
  `max_jobs` INT DEFAULT 3,
  `license` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`identifier`),
  KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Character appearance, kept in the format of the creator that wrote it
CREATE TABLE IF NOT EXISTS `multicore_appearance` (
  `citizenid` VARCHAR(50) NOT NULL,
  `format` VARCHAR(20) NOT NULL,
  `skin` LONGTEXT DEFAULT NULL,
  `comps` LONGTEXT DEFAULT NULL,
  `comp_tints` LONGTEXT DEFAULT NULL,
  `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `format`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Switch-over import (mcimport vorp | rsg, server/multi/import.lua). The old tables are only read.
-- What was brought over from which old row: a second run skips everything listed here.
-- source = 'vorp' or 'rsg', with '@<database>' when the old tables were read from another database.
CREATE TABLE IF NOT EXISTS `multicore_import_map` (
  `source` VARCHAR(80) NOT NULL,
  `kind` VARCHAR(24) NOT NULL,
  `source_key` VARCHAR(150) NOT NULL,
  `target_key` VARCHAR(150) DEFAULT NULL,
  `status` VARCHAR(10) NOT NULL DEFAULT 'done',
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`source`, `kind`, `source_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Everything an import run could not bring over, one line each (run = the time the run started)
CREATE TABLE IF NOT EXISTS `multicore_import_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `run` BIGINT NOT NULL,
  `source` VARCHAR(80) NOT NULL,
  `step` VARCHAR(24) NOT NULL,
  `source_key` VARCHAR(150) DEFAULT NULL,
  `message` TEXT DEFAULT NULL,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `run` (`run`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Jobs and grades imported characters hold that no job list here knew. Added again on every start,
-- so those characters keep their job after a restart.
CREATE TABLE IF NOT EXISTS `multicore_import_jobs` (
  `name` VARCHAR(50) NOT NULL,
  `grade` INT NOT NULL DEFAULT 0,
  `label` VARCHAR(100) DEFAULT NULL,
  PRIMARY KEY (`name`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
