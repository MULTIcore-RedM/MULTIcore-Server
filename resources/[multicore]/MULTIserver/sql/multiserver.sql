-- MULTIserver: whitelist table (also created by the resource on start)
CREATE TABLE IF NOT EXISTS `multiserver_whitelist` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL,
    `note` VARCHAR(150) DEFAULT NULL,
    `added_by` VARCHAR(100) DEFAULT NULL,
    `created` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
