-- Demo rows for mobile field testing (run AFTER mobile_rts_system.sql or on existing rts_system).
-- Safe to re-run: uses REPLACE / DELETE+INSERT for demo IDs only.

USE `rts_system`;

-- Customers (field app dropdowns / quotations)
DELETE FROM `setup_customer` WHERE `id` BETWEEN 1 AND 10;
INSERT INTO `setup_customer` (`id`, `name`, `address`, `tin_no`, `terms`, `terms_type`, `status`, `date_created`) VALUES
(1, 'Blake Russ', 'Cebu City', '301-111-111-000', 30, 'IN DAYS', 'ACTIVE', NOW()),
(2, 'Sean Paul Dorio', 'Mandaue City', '301-222-222-000', 30, 'IN DAYS', 'ACTIVE', NOW()),
(3, 'Kristian Magsayo', 'Cebu City', '301-333-333-000', 30, 'IN DAYS', 'ACTIVE', NOW()),
(4, 'Naruto Uzumaki', 'Konoha Village', '301-444-444-000', 30, 'IN DAYS', 'ACTIVE', NOW()),
(5, 'Mamarazi Co.', 'Cebu Business Park', '301-555-555-000', 30, 'IN DAYS', 'ACTIVE', NOW()),
(6, 'Mamarazi Co. — Warehouse', 'Mandaue City', '301-555-556-000', 30, 'IN DAYS', 'ACTIVE', NOW());

-- Items with barcodes (required for DR scanner / product scan)
DELETE FROM `setup_items` WHERE `id` BETWEEN 1 AND 10;
INSERT INTO `setup_items` (`id`, `brand_id`, `model_id`, `item_name`, `barcode`, `unit_measure_id`, `status`, `date_created`) VALUES
(1, 6, 6, 'Monitor 24in', 'ITEM-MON-001', 5, 'ACTIVE', NOW()),
(2, 6, 6, 'Samsung TV 55in', 'ITEM-TV-055', 5, 'ACTIVE', NOW()),
(3, 1, 1, 'Window Type Inverter', 'ITEM-INV-001', 5, 'ACTIVE', NOW());

-- Clear demo transactions only (ids 1–20)
DELETE FROM `quotation_details` WHERE `quotation_id` BETWEEN 1 AND 20;
DELETE FROM `quotation_main` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `purchase_details` WHERE `po_id` BETWEEN 1 AND 20;
DELETE FROM `purchase_main` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `receiving_details` WHERE `receiving_id` BETWEEN 1 AND 20;
DELETE FROM `receiving_main` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `outslip_details` WHERE `outslip_id` BETWEEN 1 AND 20;
DELETE FROM `outslip_main` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `delivery_details` WHERE `delivery_id` BETWEEN 1 AND 20;
DELETE FROM `delivery_main` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `billing_payments` WHERE `billing_id` BETWEEN 1 AND 20;
DELETE FROM `billing` WHERE `id` BETWEEN 1 AND 20;
DELETE FROM `gate_pass_main` WHERE `outslip_id` BETWEEN 1 AND 20;

INSERT INTO `quotation_main` (`id`, `customer_id`, `customer_name`, `quotation_no`, `quotation_date`, `quotation_total`, `prepared_by`, `status`, `date_created`) VALUES
(1, 5, 'Mamarazi Co.', 'QTN-00001', CURDATE(), 15600.00, 1, 'PENDING', NOW()),
(2, 6, 'Mamarazi Co. — Warehouse', 'QTN-00002', CURDATE(), 9800.00, 1, 'PENDING', NOW()),
(3, 1, 'Blake Russ', 'QTN-00003', CURDATE(), 12500.00, 1, 'APPROVED', NOW()),
(4, 2, 'Sean Paul Dorio', 'QTN-00004', CURDATE(), 8900.00, 1, 'APPROVED', NOW()),
(5, 4, 'Naruto Uzumaki', 'QTN-00005', CURDATE(), 4200.00, 1, 'PENDING', NOW());

INSERT INTO `quotation_details` (`quotation_id`, `item_id`, `item_name`, `qty`, `price`, `amount`) VALUES
(1, 3, 'Window Type Inverter', 1, 15600.00, 15600.00),
(2, 1, 'Monitor 24in', 1, 9800.00, 9800.00),
(3, 2, 'Samsung TV 55in', 1, 12500.00, 12500.00),
(4, 1, 'Monitor 24in', 1, 8900.00, 8900.00),
(5, 3, 'Window Type Inverter', 1, 4200.00, 4200.00);

-- Minimal DR chain for Blake (scanner test): PO → receive → outslip → DR out for delivery
INSERT INTO `purchase_main` (`id`, `quotation_id`, `supplier_id`, `supplier_name`, `po_no`, `po_date`, `po_total`, `prepared_by`, `status`, `date_created`) VALUES
(1, 3, 1, 'Mamarazi Co.', 'PO-00001', CURDATE(), 12500.00, 1, 'COMPLETED', NOW());

INSERT INTO `purchase_details` (`po_id`, `item_id`, `item_name`, `qty`, `price`, `amount`) VALUES
(1, 2, 'Samsung TV 55in', 1, 12500.00, 12500.00);

INSERT INTO `receiving_main` (`id`, `po_id`, `receiving_no`, `receiving_date`, `branch_id`, `status`, `date_created`) VALUES
(1, 1, 'RCV-00001', CURDATE(), 1, 'COMPLETED', NOW());

INSERT INTO `receiving_details` (`receiving_id`, `item_id`, `qty`) VALUES
(1, 2, 1);

INSERT INTO `outslip_main` (`id`, `customer_id`, `customer_name`, `outslip_no`, `outslip_date`, `receiving_id`, `branch_id`, `prepared_by`, `status`, `date_created`) VALUES
(1, 1, 'Blake Russ', 'OS-00001', CURDATE(), 1, 1, 1, 'FOR_DISPATCH', NOW());

INSERT INTO `outslip_details` (`outslip_id`, `item_id`, `item_name`, `qty`, `price`, `amount`) VALUES
(1, 2, 'Samsung TV 55in', 1, 12500.00, 12500.00);

INSERT INTO `delivery_main` (`id`, `outslip_id`, `dr_no`, `dr_date`, `customer_id`, `customer_name`, `dr_total`, `status`, `date_created`) VALUES
(1, 1, 'DR-00001', CURDATE(), 1, 'Blake Russ', 12500.00, 'OUT FOR DELIVERY', NOW());

INSERT INTO `delivery_details` (`delivery_id`, `item_id`, `item_name`, `qty`, `price`, `amount`, `serial_no`) VALUES
(1, 2, 'Samsung TV 55in', 1, 12500.00, 12500.00, NULL);
