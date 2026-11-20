-- ============================================================
-- MULTIinventory schema - version 2
--
-- Applied automatically on resource start by server/core/db.lua
-- (idempotent: CREATE TABLE IF NOT EXISTS + column/index checks).
-- Can also be run by hand:  mysql -u root <database> < sql/install.sql
--
-- Item definitions come from rsg-core's item list (MULTIcore shared/items.lua and
-- everything added at runtime) and from the VORP-style `items` table, which is created
-- here (empty) so VORP item install SQL works on a MULTIcore server.
--
-- Statement rule for the auto-migrator: every statement ends with ';' at
-- the end of a line; no ';' inside comments or strings.
-- ============================================================

CREATE TABLE IF NOT EXISTS `multiinv_schema` (
  `version`     INT          NOT NULL PRIMARY KEY,
  `applied_at`  BIGINT       NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- VORP-style item rows (weight in kg). Rows here win over rsg-core's list for the same name.
CREATE TABLE IF NOT EXISTS `items` (
  `item` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `limit` INT NOT NULL DEFAULT 1,
  `can_remove` TINYINT(1) NOT NULL DEFAULT 1,
  `type` VARCHAR(50) NULL DEFAULT 'item_standard',
  `usable` TINYINT(1) NULL DEFAULT 0,
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `groupId` INT UNSIGNED NOT NULL DEFAULT 1,
  `rarityId` INT NOT NULL DEFAULT 1,
  `metadata` LONGTEXT NULL,
  `desc` VARCHAR(5550) NOT NULL DEFAULT '',
  `weight` FLOAT NOT NULL DEFAULT 0.25,
  PRIMARY KEY (`item`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `item_group` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `description` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `item_group` (`id`, `description`) VALUES (1, 'default');

CREATE TABLE IF NOT EXISTS `item_rarity` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `item_rarity` (`id`, `name`) VALUES (1, 'Common');

-- Optional per-item extras that the `items` table has no column for.
CREATE TABLE IF NOT EXISTS `multiinv_item_ext` (
  `item`            VARCHAR(50)  NOT NULL PRIMARY KEY,
  `image`           VARCHAR(100) NULL,
  `category`        VARCHAR(32)  NULL,
  `clothing_key`    VARCHAR(32)  NULL,
  `hotbar`          TINYINT(1)   NOT NULL DEFAULT 1,
  `extra`           LONGTEXT     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Every place that holds items and has its own definition
-- ('player:12', 'equip:12', 'drop:55', '<registered secondary id>').
CREATE TABLE IF NOT EXISTS `multiinv_containers` (
  `id`              VARCHAR(100) NOT NULL PRIMARY KEY,
  `kind`            VARCHAR(16)  NOT NULL,
  `owner_charid`    INT          NULL,
  `label`           VARCHAR(100) NULL,
  `slots`           INT          NOT NULL DEFAULT 50,
  `max_weight`      DECIMAL(10,2) NULL,
  `flags`           LONGTEXT     NULL,
  `perms`           LONGTEXT     NULL,
  `created_at`      BIGINT       NOT NULL,
  `updated_at`      BIGINT       NOT NULL,
  KEY `idx_owner` (`owner_charid`),
  KEY `idx_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Item stacks (non-weapon). One row per occupied slot.
-- id = the "item id" exposed through the API; allocated by the server in
-- blocks (Config.Persistence.idBlock), so external writers must use the
-- exports or run while the resource is stopped.
CREATE TABLE IF NOT EXISTS `multiinv_stacks` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `container_id`    VARCHAR(100) NOT NULL,
  `slot`            SMALLINT     NOT NULL,
  `item`            VARCHAR(50)  NOT NULL,
  `count`           INT          NOT NULL,
  `metadata`        LONGTEXT     NOT NULL,
  `meta_hash`       CHAR(40)     NOT NULL,
  `created_at`      BIGINT       NOT NULL,
  `decay_at`        BIGINT       NULL,
  `legacy_crafted_id` INT        NULL,
  `migration_batch` INT          NULL,
  `updated_at`      BIGINT       NOT NULL,
  UNIQUE KEY `uq_slot` (`container_id`, `slot`),
  KEY `idx_item` (`container_id`, `item`, `meta_hash`),
  KEY `idx_name` (`item`),
  KEY `idx_batch` (`migration_batch`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Weapons (unique; weapons part). Ids are preserved from `loadout.id` on migration.
CREATE TABLE IF NOT EXISTS `multiinv_weapons` (
  `id`              INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `container_id`    VARCHAR(100) NOT NULL,
  `slot`            SMALLINT     NOT NULL,
  `owner_charid`    INT          NULL,
  `name`            VARCHAR(50)  NOT NULL,
  `label`           VARCHAR(50)  NULL,
  `serial`          VARCHAR(50)  NULL,
  `custom_label`    VARCHAR(50)  NULL,
  `custom_desc`     VARCHAR(255) NULL,
  `ammo`            LONGTEXT     NOT NULL,
  `components`      LONGTEXT     NOT NULL,
  `comps`           LONGTEXT     NOT NULL,
  `dirt`            DECIMAL(20,6) NOT NULL DEFAULT 0,
  `soot`            DECIMAL(20,6) NOT NULL DEFAULT 0,
  `degradation`     DECIMAL(20,6) NOT NULL DEFAULT 0,
  `damage`          DECIMAL(20,6) NOT NULL DEFAULT 0,
  `equipped`        VARCHAR(16)  NULL,
  `metadata`        LONGTEXT     NOT NULL,
  `legacy_loadout_id` INT        NULL,
  `migration_batch` INT          NULL,
  `updated_at`      BIGINT       NOT NULL,
  UNIQUE KEY `uq_serial` (`serial`),
  KEY `idx_container` (`container_id`),
  KEY `idx_batch` (`migration_batch`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Gunbelt ammo per character.
CREATE TABLE IF NOT EXISTS `multiinv_ammo` (
  `charid`          INT          NOT NULL,
  `ammo_type`       VARCHAR(50)  NOT NULL,
  `count`           INT          NOT NULL,
  `migration_batch` INT          NULL,
  PRIMARY KEY (`charid`, `ammo_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Hotbar 1..5. ref_id = stack id (item) or weapon id; `item` is the
-- fallback when that stack is gone (another stack of the same item is used).
CREATE TABLE IF NOT EXISTS `multiinv_hotbar` (
  `charid`          INT          NOT NULL,
  `slot`            TINYINT      NOT NULL,
  `ref_kind`        VARCHAR(8)   NOT NULL,
  `ref_id`          BIGINT       NOT NULL,
  `item`            VARCHAR(50)  NULL,
  PRIMARY KEY (`charid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wardrobe outfits = named sets of owned clothing stacks.
CREATE TABLE IF NOT EXISTS `multiinv_outfits` (
  `id`              INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `charid`          INT          NOT NULL,
  `name`            VARCHAR(64)  NOT NULL,
  `pieces`          LONGTEXT     NOT NULL,
  `created_at`      BIGINT       NOT NULL,
  KEY `idx_char` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- World drops (Config.Drop.mode = 'world'). The pile's items are stacks in
-- container `drop:<id>`; a pile is removed when empty or at expires_at.
CREATE TABLE IF NOT EXISTS `multiinv_drops` (
  `id`              INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `container_id`    VARCHAR(100) NOT NULL,
  `x`               DOUBLE       NOT NULL,
  `y`               DOUBLE       NOT NULL,
  `z`               DOUBLE       NOT NULL,
  `owner_charid`    INT          NULL,
  `created_at`      BIGINT       NOT NULL DEFAULT 0,
  `expires_at`      BIGINT       NOT NULL,
  KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit log (admin actions, gives, drops, pick-ups, deletes, robberies).
-- data = JSON incl. the full stacks (item, count, metadata) for restores.
CREATE TABLE IF NOT EXISTS `multiinv_log` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `at`              BIGINT       NOT NULL,
  `actor_charid`    INT          NULL,
  `actor`           VARCHAR(64)  NULL,
  `target_charid`   INT          NULL,
  `action`          VARCHAR(32)  NOT NULL,
  `container_from`  VARCHAR(100) NULL,
  `container_to`    VARCHAR(100) NULL,
  `item`            VARCHAR(50)  NULL,
  `count`           INT          NULL,
  `data`            LONGTEXT     NULL,
  KEY `idx_at` (`at`),
  KEY `idx_actor` (`actor_charid`),
  KEY `idx_target` (`target_charid`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Workshop: placed work stations (grinding wheel, spinning wheel, mortar). Removed at expires_at.
CREATE TABLE IF NOT EXISTS `multiinv_stations` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `type`            VARCHAR(32)  NOT NULL,
  `owner_charid`    INT          NOT NULL,
  `x`               DOUBLE       NOT NULL,
  `y`               DOUBLE       NOT NULL,
  `z`               DOUBLE       NOT NULL,
  `heading`         DOUBLE       NOT NULL DEFAULT 0,
  `created_at`      BIGINT       NOT NULL,
  `expires_at`      BIGINT       NOT NULL,
  KEY `idx_expires` (`expires_at`),
  KEY `idx_owner` (`owner_charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Workshop: recipe books a character has read (Crafting Journal recipes with unlock = book).
CREATE TABLE IF NOT EXISTS `multiinv_recipes_known` (
  `charid`          INT          NOT NULL,
  `book`            VARCHAR(64)  NOT NULL,
  `learned_at`      BIGINT       NOT NULL,
  PRIMARY KEY (`charid`, `book`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration bookkeeping (data imports)
CREATE TABLE IF NOT EXISTS `multiinv_migration` (
  `batch`           INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `step`            VARCHAR(32)  NOT NULL,
  `status`          VARCHAR(16)  NOT NULL,
  `source_rows`     INT          NOT NULL DEFAULT 0,
  `target_rows`     INT          NOT NULL DEFAULT 0,
  `source_checksum` VARCHAR(64)  NULL,
  `target_checksum` VARCHAR(64)  NULL,
  `report`          LONGTEXT     NULL,
  `started_at`      BIGINT       NOT NULL,
  `finished_at`     BIGINT       NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `multiinv_schema` (`version`, `applied_at`) VALUES (1, UNIX_TIMESTAMP());
INSERT IGNORE INTO `multiinv_schema` (`version`, `applied_at`) VALUES (2, UNIX_TIMESTAMP());
