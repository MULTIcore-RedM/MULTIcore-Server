-- MULTIwagons: made by itself on the first start (and missing columns are added).
-- Only needed if you set up the database by hand.
-- The table keeps the name `rsg_wagons` so wagons from earlier versions carry over.
CREATE TABLE IF NOT EXISTS `rsg_wagons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL DEFAULT '0',
  `wagon` varchar(50) NOT NULL DEFAULT '0',
  `custom` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '{}',
  `animals` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '[]',
  `active` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- an older table: add what is missing (MariaDB)
ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `citizenid` varchar(50) NOT NULL DEFAULT '0';
ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `wagon` varchar(50) NOT NULL DEFAULT '0';
ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `custom` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '{}';
ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `animals` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '[]';
ALTER TABLE `rsg_wagons` ADD COLUMN IF NOT EXISTS `active` int(11) NOT NULL DEFAULT 0;
