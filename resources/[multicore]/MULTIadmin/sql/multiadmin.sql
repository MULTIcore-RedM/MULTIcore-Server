-- MULTIadmin bans. The resource also creates this table on start.
CREATE TABLE IF NOT EXISTS `multicore_bans` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NULL,
    `license` VARCHAR(80) NULL,
    `license2` VARCHAR(80) NULL,
    `steam` VARCHAR(80) NULL,
    `discord` VARCHAR(80) NULL,
    `fivem` VARCHAR(80) NULL,
    `reason` VARCHAR(255) NOT NULL DEFAULT '',
    `expire` BIGINT NOT NULL DEFAULT 0,          -- unix time, 0 = permanent
    `bannedby` VARCHAR(100) NOT NULL DEFAULT '',
    `created` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `license` (`license`),
    KEY `steam` (`steam`),
    KEY `discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
