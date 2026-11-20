-- MULTIdoors: lock rules made in game with /doors (the script creates this table by itself on start).
-- data = the rule as JSON; { "disabled": true } switches off the config rule with the same id.
CREATE TABLE IF NOT EXISTS `multicore_doors` (
    `id` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `updated_by` VARCHAR(64) DEFAULT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
