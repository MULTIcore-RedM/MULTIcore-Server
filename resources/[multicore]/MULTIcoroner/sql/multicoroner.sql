-- MULTIcoroner: made by itself on the first start. Only needed if you set up the database by hand.
CREATE TABLE IF NOT EXISTS `multicoroner_reports` (
    `id` int unsigned NOT NULL AUTO_INCREMENT,
    `report_id` varchar(32) NOT NULL,
    `created_at` datetime NOT NULL,
    `subject_type` varchar(20) NOT NULL DEFAULT 'NPC',
    `subject_id` int unsigned NOT NULL DEFAULT 0,
    `subject_name` varchar(80) NOT NULL DEFAULT '',
    `location` varchar(120) NOT NULL DEFAULT '',
    `identified_name` varchar(80) NOT NULL DEFAULT '',
    `cause` varchar(120) NOT NULL,
    `manner` varchar(40) NOT NULL DEFAULT 'UNDETERMINED',
    `notes` text,
    `conclusion` varchar(120) NOT NULL,
    `coroner` varchar(80) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    UNIQUE KEY `multicoroner_report_id_unique` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
