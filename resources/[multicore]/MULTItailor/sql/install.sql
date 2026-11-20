-- MULTItailor - database tables. The resource creates them itself on start (CREATE TABLE IF NOT
-- EXISTS); this file is only for a manual install. Safe to run more than once.

-- Pattern book of every tailor shop.
CREATE TABLE IF NOT EXISTS `multitailor_patterns` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `business_id` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `sex` VARCHAR(8) NOT NULL,
    `pieces` LONGTEXT NOT NULL,
    `created_by` VARCHAR(128) NULL,
    `created_cid` VARCHAR(64) NULL,
    `created_at` BIGINT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_meta` (
    `k` VARCHAR(64) NOT NULL,
    `v` TEXT NULL,
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_till` (
    `business_id` VARCHAR(64) NOT NULL,
    `balance` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_till_log` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `business_id` VARCHAR(64) NOT NULL,
    `type` VARCHAR(24) NOT NULL,
    `amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `by_name` VARCHAR(128) NULL,
    `note` VARCHAR(160) NULL,
    `created_at` BIGINT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_shelf` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `business_id` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `label` VARCHAR(80) NULL,
    `metadata` LONGTEXT NULL,
    `qty` INT NOT NULL DEFAULT 0,
    `price` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `stocked_by` VARCHAR(128) NULL,
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_orders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `business_id` VARCHAR(64) NOT NULL,
    `customer_name` VARCHAR(128) NOT NULL,
    `customer_cid` VARCHAR(64) NOT NULL,
    `sex` VARCHAR(8) NOT NULL,
    `request` TEXT NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'open',
    `handled_by` VARCHAR(128) NULL,
    `created_at` BIGINT NOT NULL,
    `updated_at` BIGINT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`, `status`),
    KEY `idx_customer` (`customer_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `multitailor_stores` (
    `id` VARCHAR(48) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `updated_by` VARCHAR(128) NULL,
    `updated_at` BIGINT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
