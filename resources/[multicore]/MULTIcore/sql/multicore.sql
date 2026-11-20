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
