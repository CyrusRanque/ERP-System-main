-- Idempotent mobile schema alignment (canonical copy: C:\databases-mobile\rts_mobile_schema_align.sql)
-- Matches erp-server/config/mobileSchema.js + Flutter field workflows.
USE `rts_system`;

DROP PROCEDURE IF EXISTS `sp_rts_mobile_schema_align`;
DELIMITER //
CREATE PROCEDURE `sp_rts_mobile_schema_align`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'setup_items' AND COLUMN_NAME = 'barcode'
  ) THEN
    ALTER TABLE `setup_items` ADD COLUMN `barcode` VARCHAR(64) NULL AFTER `item_name`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'setup_items' AND INDEX_NAME = 'setup_items_barcode_idx'
  ) THEN
    CREATE INDEX `setup_items_barcode_idx` ON `setup_items` (`barcode`);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'inventory' AND COLUMN_NAME = 'item_id'
  ) THEN
    ALTER TABLE `inventory` ADD COLUMN `item_id` INT NOT NULL DEFAULT 0 AFTER `branch_id`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_main' AND COLUMN_NAME = 'outslip_id'
  ) THEN
    ALTER TABLE `delivery_main` ADD COLUMN `outslip_id` INT NOT NULL DEFAULT 0 AFTER `id`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'purchase_main' AND COLUMN_NAME = 'quotation_id'
  ) THEN
    ALTER TABLE `purchase_main` ADD COLUMN `quotation_id` INT NOT NULL DEFAULT 0 AFTER `id`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'receiving_main' AND COLUMN_NAME = 'po_id'
  ) THEN
    ALTER TABLE `receiving_main` ADD COLUMN `po_id` INT NOT NULL DEFAULT 0 AFTER `id`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'billing' AND COLUMN_NAME = 'paid_amount'
  ) THEN
    ALTER TABLE `billing` ADD COLUMN `paid_amount` DOUBLE NOT NULL DEFAULT 0 AFTER `billing_total`;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'receiving_details' AND COLUMN_NAME = 'item_name'
  ) THEN
    ALTER TABLE `receiving_details` ADD COLUMN `item_name` TEXT NULL AFTER `item_id`;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts' AND COLUMN_NAME = 'contract_no'
  ) THEN
    ALTER TABLE `ar_contracts` ADD COLUMN `contract_no` VARCHAR(255) NULL AFTER `id`;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts' AND COLUMN_NAME = 'monthly_fee'
  ) THEN
    ALTER TABLE `ar_contracts` ADD COLUMN `monthly_fee` DOUBLE NOT NULL DEFAULT 0 AFTER `contract_amount`;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ar_contracts' AND COLUMN_NAME = 'billing_day'
  ) THEN
    ALTER TABLE `ar_contracts` ADD COLUMN `billing_day` TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `end_date`;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'outslip_details'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'outslip_details' AND COLUMN_NAME = 'price'
  ) THEN
    ALTER TABLE `outslip_details` ADD COLUMN `price` DOUBLE NOT NULL DEFAULT 0 AFTER `qty`;
    ALTER TABLE `outslip_details` ADD COLUMN `amount` DOUBLE NOT NULL DEFAULT 0 AFTER `price`;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'gate_pass_main'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'gate_pass_main' AND COLUMN_NAME = 'destination'
  ) THEN
    ALTER TABLE `gate_pass_main` ADD COLUMN `destination` VARCHAR(255) NULL AFTER `plate_no`;
    ALTER TABLE `gate_pass_main` ADD COLUMN `exit_at` DATETIME NULL AFTER `status`;
  END IF;
END//
DELIMITER ;

CALL `sp_rts_mobile_schema_align`();
DROP PROCEDURE IF EXISTS `sp_rts_mobile_schema_align`;
