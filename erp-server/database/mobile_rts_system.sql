/*
RTS ERP — MySQL database: rts_system
MOBILE + erp-server reference (Flutter field app + Node API)

Export type: CLEAN REFERENCE — schema + master setup seeds only
Updated: 2026-10-29
Aligned with: erp-server/config/mobileSchema.js (30 tables, barcode + fulfillment columns)

IMPORT (WAMP phpMyAdmin or mysql CLI):
  Full import DROPs and recreates listed tables. Back up live data first.

AFTER IMPORT:
  1) erp-server/.env → DB_NAME=rts_system
  2) cd C:\\ERP-System-main\\erp-server && npm start
  3) Phone → Server → YOUR_PC_IP:8000 → Save & connect
  4) Mobile login: admin / p@ssw0rd (plaintext OK for Node API; hash via Laravel if using office web)

OPTIONAL demo transactions: C:\\erp-system\\database\\demo_reference_seed.sql

Health check: http://YOUR_PC_IP:8000/api/mobile/health → itemBarcodes: ok, api: node-mobile
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
CREATE DATABASE /*!32312 IF NOT EXISTS*/`rts_system` /*!40100 DEFAULT CHARACTER SET latin1 */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `rts_system`;

/*Table structure for table `accomplishment_details` */

DROP TABLE IF EXISTS `accomplishment_details`;

CREATE TABLE `accomplishment_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `accomplishment_id` int DEFAULT NULL,
  `path_url` text,
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `accomplishment_details` */

/*Table structure for table `accomplishment_main` */

DROP TABLE IF EXISTS `accomplishment_main`;

CREATE TABLE `accomplishment_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `accomplishment_no` varchar(255) DEFAULT NULL,
  `accomplishment_date` date DEFAULT NULL,
  `project_id` int DEFAULT NULL,
  `remarks` text,
  `prepared_by` int DEFAULT '0',
  `status` varchar(20) DEFAULT 'ACTIVE' COMMENT 'ACTIVE,INACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `accomplishment_main` */

/*Table structure for table `billing` */

DROP TABLE IF EXISTS `billing_payments`;
DROP TABLE IF EXISTS `billing`;

CREATE TABLE `billing` (
  `id` int NOT NULL AUTO_INCREMENT,
  `delivery_id` int DEFAULT '0',
  `billing_no` varchar(255) DEFAULT NULL,
  `billing_date` date DEFAULT NULL,
  `customer_id` int DEFAULT '0',
  `customer_name` text,
  `billing_total` double DEFAULT '0',
  `paid_amount` double DEFAULT '0',
  `prepared_by` int DEFAULT '0',
  `status` varchar(20) DEFAULT 'ACTIVE' COMMENT 'ACTIVE,INACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `billing` */

/*Table structure for table `billing_payments` */

CREATE TABLE `billing_payments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `billing_id` int DEFAULT '0',
  `payment_no` varchar(255) DEFAULT NULL,
  `payment_date` date DEFAULT NULL,
  `amount` double DEFAULT '0',
  `reference` varchar(255) DEFAULT NULL,
  `remarks` text,
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `billing_payments` */

/*Table structure for table `customer_ledger` */

DROP TABLE IF EXISTS `customer_ledger`;

CREATE TABLE `customer_ledger` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int DEFAULT '0',
  `outslip_id` int DEFAULT '0',
  `debit` double DEFAULT '0',
  `credit` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `customer_ledger` */

/*Table structure for table `delivery_details` */

DROP TABLE IF EXISTS `delivery_details`;

CREATE TABLE `delivery_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `delivery_id` int DEFAULT '0',
  `item_id` int DEFAULT '0',
  `item_name` text,
  `qty` double DEFAULT '0',
  `price` double DEFAULT '0',
  `amount` double DEFAULT '0',
  `serial_no` text,
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `delivery_details` */

/*Table structure for table `delivery_main` */

DROP TABLE IF EXISTS `delivery_main`;

CREATE TABLE `delivery_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `outslip_id` int DEFAULT '0',
  `dr_no` varchar(255) DEFAULT NULL,
  `dr_date` date DEFAULT NULL,
  `customer_id` int DEFAULT '0',
  `customer_name` text,
  `dr_total` double DEFAULT '0',
  `prepared_by` int DEFAULT '0',
  `delivered_by` int DEFAULT NULL,
  `status` varchar(20) DEFAULT 'PENDING' COMMENT 'PENDING,OUT FOR DELIVERY,DELIVERED,INACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `delivery_main` */

/*Table structure for table `inventory` */

DROP TABLE IF EXISTS `inventory`;

CREATE TABLE `inventory` (
  `id` int NOT NULL AUTO_INCREMENT,
  `branch_id` int DEFAULT '0',
  `item_id` int DEFAULT '0',
  `trans_id` int DEFAULT '0',
  `trans_date` date DEFAULT NULL,
  `trans_type` varchar(100) DEFAULT NULL,
  `in` double DEFAULT '0',
  `out` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `inventory` */

/*Table structure for table `purchase_details` */

DROP TABLE IF EXISTS `purchase_details`;

CREATE TABLE `purchase_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int DEFAULT '0',
  `item_id` int DEFAULT '0',
  `item_name` text,
  `qty` double DEFAULT NULL,
  `price` double DEFAULT '0',
  `amount` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `purchase_details` */

/*Table structure for table `purchase_main` */

DROP TABLE IF EXISTS `purchase_main`;

CREATE TABLE `purchase_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `quotation_id` int DEFAULT '0',
  `supplier_id` int DEFAULT '0',
  `supplier_name` text,
  `po_no` varchar(255) DEFAULT NULL,
  `po_date` date DEFAULT NULL,
  `po_total` double DEFAULT '0',
  `prepared_by` int DEFAULT '0',
  `approved_by` int DEFAULT '0',
  `status` varchar(20) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT 'PENDING' COMMENT 'ACTIVE,INACTIVE,PENDING',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `purchase_main` */

/*Table structure for table `quotation_details` */

DROP TABLE IF EXISTS `quotation_details`;

CREATE TABLE `quotation_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `quotation_id` int DEFAULT '0',
  `item_id` int DEFAULT '0',
  `item_name` text,
  `qty` double DEFAULT '0',
  `price` double DEFAULT '0',
  `amount` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `quotation_details` */

/*Table structure for table `quotation_main` */

DROP TABLE IF EXISTS `quotation_main`;

CREATE TABLE `quotation_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int DEFAULT NULL,
  `customer_name` text,
  `quotation_no` varchar(255) DEFAULT NULL,
  `quotation_date` date DEFAULT NULL,
  `quotation_total` double DEFAULT '0',
  `prepared_by` int DEFAULT '0',
  `approved_by` int DEFAULT '0',
  `status` varchar(20) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT 'PENDING' COMMENT 'ACTIVE,INACTIVE,PENDING',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `quotation_main` */

/*Table structure for table `receiving_details` */

DROP TABLE IF EXISTS `receiving_details`;

CREATE TABLE `receiving_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `receiving_id` int DEFAULT NULL,
  `item_id` int DEFAULT '0',
  `qty` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `receiving_details` */

/*Table structure for table `receiving_main` */

DROP TABLE IF EXISTS `receiving_main`;

CREATE TABLE `receiving_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int DEFAULT '0',
  `receiving_no` varchar(255) DEFAULT NULL,
  `receiving_date` date DEFAULT NULL,
  `branch_id` int DEFAULT '0',
  `remarks` text,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `receiving_main` */

/*Table structure for table `setup_branch` */

DROP TABLE IF EXISTS `setup_branch`;

CREATE TABLE `setup_branch` (
  `id` int NOT NULL AUTO_INCREMENT,
  `company_id` int DEFAULT '0',
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

/*Data for the table `setup_branch` */

insert  into `setup_branch`(`id`,`company_id`,`name`,`status`,`date_created`) values 
(1,1,'RTS-MAIN','ACTIVE','2026-08-19 09:34:27'),
(2,2,'RSC-MAIN','ACTIVE','2026-08-19 09:34:35');

/*Table structure for table `setup_brand` */

DROP TABLE IF EXISTS `setup_brand`;

CREATE TABLE `setup_brand` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=34 DEFAULT CHARSET=latin1;

/*Data for the table `setup_brand` */

insert  into `setup_brand`(`id`,`name`,`status`,`date_created`) values 
(1,'HIKVISION','ACTIVE','2026-08-19 09:23:51'),
(2,'DAHUA','ACTIVE','2026-08-19 09:23:56'),
(3,'IMOU','ACTIVE','2026-08-19 09:23:59'),
(4,'CISCO','ACTIVE','2026-08-19 09:24:03'),
(5,'UBIQUITI','ACTIVE','2026-08-19 09:24:07'),
(6,'SAMSUNG','ACTIVE','2026-08-19 09:24:48'),
(7,'SUNMI','ACTIVE','2026-08-19 09:24:51'),
(8,'BOSCH','ACTIVE','2026-08-19 09:25:37'),
(9,'LOTUS','ACTIVE','2026-08-19 09:25:40'),
(10,'KEN','ACTIVE','2026-08-19 09:25:49'),
(11,'EPSON','ACTIVE','2026-08-19 09:25:52'),
(12,'HP','ACTIVE','2026-08-19 09:25:56'),
(13,'INGCO','ACTIVE','2026-08-19 09:26:01'),
(14,'TPLINK','ACTIVE','2026-08-19 09:26:16'),
(15,'ANKER','ACTIVE','2026-08-19 09:26:35'),
(16,'RUIJIE','ACTIVE','2026-08-19 09:26:49'),
(17,'BROTHER','ACTIVE','2026-08-19 09:27:00'),
(18,'ROYU','ACTIVE','2026-08-19 09:27:17'),
(19,'APC','ACTIVE','2026-08-19 09:27:37'),
(20,'COMLINK','ACTIVE','2026-08-19 09:27:46'),
(21,'VSOL','ACTIVE','2026-08-19 09:27:59'),
(22,'SEAGATE','ACTIVE','2026-08-19 09:28:09'),
(23,'PREMIUM LINE','ACTIVE','2026-08-19 09:28:14'),
(24,'OMADA BY TPLINK','ACTIVE','2026-08-19 09:28:27'),
(25,'ZKTECO','ACTIVE','2026-08-19 09:28:37'),
(26,'ITC','ACTIVE','2026-08-19 09:28:45'),
(27,'SPON','ACTIVE','2026-08-19 09:28:47'),
(28,'GOODWE','ACTIVE','2026-08-19 09:29:01'),
(29,'TIANDY','ACTIVE','2026-08-19 09:29:03'),
(30,'PANASONIC','ACTIVE','2026-08-19 09:29:13'),
(31,'ONTI','ACTIVE','2026-08-19 09:29:28'),
(32,'CCA','ACTIVE','2026-08-19 09:29:30'),
(33,'WESTERN DIGITAL','ACTIVE','2026-08-19 10:01:02');

/*Table structure for table `setup_category` */

DROP TABLE IF EXISTS `setup_category`;

CREATE TABLE `setup_category` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

/*Data for the table `setup_category` */

insert  into `setup_category`(`id`,`name`,`status`,`date_created`) values 
(1,'IP CAMERA','ACTIVE','2026-08-19 09:35:25'),
(2,'NVR','ACTIVE','2026-08-19 09:36:52'),
(3,'DVR','ACTIVE','2026-08-19 09:36:57'),
(4,'SWITCHES/ROUTER','ACTIVE','2026-08-19 09:37:08'),
(5,'ANALOG CAMERA','ACTIVE','2026-08-19 09:37:24'),
(6,'CABLES','ACTIVE','2026-08-19 09:37:51');

/*Table structure for table `setup_company` */

DROP TABLE IF EXISTS `setup_company`;

CREATE TABLE `setup_company` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` text,
  `address` text,
  `contact_no` varchar(255) DEFAULT NULL,
  `tin_no` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

/*Data for the table `setup_company` */

insert  into `setup_company`(`id`,`name`,`address`,`contact_no`,`tin_no`,`status`,`date_created`) values 
(1,'RESPONSIVCODE TECHNOLOGY SOLUTIONS','RM301E-3 MEDALLE BLDG. FUENTE OSMEÑA CAPITOL SITE, CEBU CITY	','09175734911','252-890-529-000','ACTIVE','2026-08-19 09:31:11'),
(2,'RSC TECHNOLOGY AND DEVELOPMENT CORPORATION','RM301E-2 MEDALLE BLDG. FUENTE OSMEÑA CAPITOL SITE, CEBU CITY	','09175734911','690-772-316-000','ACTIVE','2026-08-19 09:32:06');

/*Table structure for table `setup_customer` */

DROP TABLE IF EXISTS `setup_customer`;

CREATE TABLE `setup_customer` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` text,
  `address` text,
  `tin_no` varchar(255) DEFAULT NULL,
  `terms` int DEFAULT NULL,
  `terms_type` varchar(20) DEFAULT 'IN DAYS',
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `setup_customer` */

/*Table structure for table `setup_items` */

DROP TABLE IF EXISTS `setup_items`;

CREATE TABLE `setup_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `brand_id` int DEFAULT '0',
  `model_id` int DEFAULT '0',
  `item_name` text,
  `barcode` varchar(64) DEFAULT NULL,
  `unit_measure_id` int DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `setup_items_barcode_idx` (`barcode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `setup_items` */

/*Table structure for table `setup_model` */

DROP TABLE IF EXISTS `setup_model`;

CREATE TABLE `setup_model` (
  `id` int NOT NULL AUTO_INCREMENT,
  `brand_id` int DEFAULT '0',
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=50 DEFAULT CHARSET=latin1;

/*Data for the table `setup_model` */

insert  into `setup_model`(`id`,`brand_id`,`name`,`status`,`date_created`) values 
(1,1,'DS-2CE76D0T-ITPFS','ACTIVE','2026-08-19 09:54:30'),
(2,1,'DS-2CD1023G0-IUF','ACTIVE','2026-08-19 09:54:41'),
(3,1,'DS-2CD2155FWD-I','ACTIVE','2026-08-19 09:54:58'),
(4,1,'DS-7204HGHI-K1','ACTIVE','2026-08-19 09:55:14'),
(5,1,'DS-7616NI-Q2','ACTIVE','2026-08-19 09:55:25'),
(6,1,'DS-2CD2047G2-L','ACTIVE','2026-08-19 09:55:39'),
(7,1,'DS-2CE72DF3T-F','ACTIVE','2026-08-19 09:55:52'),
(8,1,'DS-2CD1327G2-LUF','ACTIVE','2026-08-19 09:56:07'),
(9,1,'DS-2CD1047G0-L','ACTIVE','2026-08-19 09:56:23'),
(10,1,'DS-2CD1023G0-IU','ACTIVE','2026-08-19 09:56:38'),
(11,1,'DS-2CD2347G2-L','ACTIVE','2026-08-19 09:57:14'),
(12,1,'DS-3E0505P-EM','ACTIVE','2026-08-19 09:57:36'),
(13,1,'DS-3WR12GC','ACTIVE','2026-08-19 09:57:55'),
(14,1,'TVI-8CH4D4B-2MP-ECO','ACTIVE','2026-08-19 09:58:06'),
(15,1,'DS-3E1518P-EM','ACTIVE','2026-08-19 09:58:21'),
(16,1,'DS-2CD2T43G0-I5','ACTIVE','2026-08-19 09:58:35'),
(17,1,'DS-2DE4425IW-DE','ACTIVE','2026-08-19 09:58:45'),
(18,1,'DS-2SE4C225MWG-E','ACTIVE','2026-08-19 09:58:55'),
(19,1,'DS-1296ZJ-H','ACTIVE','2026-08-19 09:59:04'),
(20,1,'DS-3E0105P-E/M(B)','ACTIVE','2026-08-19 09:59:17'),
(21,1,'DS-9632NI-M8','ACTIVE','2026-08-19 10:01:22'),
(22,1,'DS-2CE16D0T-IRPF ','ACTIVE','2026-08-19 10:01:51'),
(23,1,'DS-7632NXI-K2(D)','ACTIVE','2026-08-19 10:02:07'),
(24,1,'DS-2CD1027G2-L','ACTIVE','2026-08-19 10:02:44'),
(25,1,'DS-2CD2155FWD-I','ACTIVE','2026-08-19 10:04:10'),
(26,1,'DS-7616NI-Q2/16P','ACTIVE','2026-08-19 10:28:32'),
(27,1,'DS-2CD1047G3-LIU','ACTIVE','2026-08-19 10:28:45'),
(28,1,'DS-7216HGHI-MI','ACTIVE','2026-08-19 10:28:58'),
(29,1,'DS-7732NXI-K4(D)','ACTIVE','2026-08-19 10:29:22'),
(30,1,'DS-3E0526P-E/M','ACTIVE','2026-08-19 10:30:10'),
(31,1,'DS-2CD1347G2-L','ACTIVE','2026-08-19 10:31:48'),
(32,1,'DS-2CD1047G2-L','ACTIVE','2026-08-19 10:32:22'),
(33,1,'DS-2CE76D0T-EXIPF','ACTIVE','2026-08-19 10:32:31'),
(34,1,'DS-3E0106HP-E','ACTIVE','2026-08-19 10:33:10'),
(35,2,'DH-PFS3206-4P-96','ACTIVE','2026-08-19 10:34:13'),
(36,2,'DH-PFS3106-4ET-60','ACTIVE','2026-08-19 10:34:25'),
(37,2,'DH-HAC-HDW1200TRQN','ACTIVE','2026-08-19 10:35:03'),
(38,2,'DH-HAC-HFW1239TLMN-LED','ACTIVE','2026-08-19 10:35:41'),
(39,2,'DH-HAC-HFW1509TLMN-LED','ACTIVE','2026-08-19 10:35:58'),
(40,2,'DH-XVR5104HS-X1','ACTIVE','2026-08-19 10:36:09'),
(41,2,'DH-XVR5104HS-I3','ACTIVE','2026-08-19 10:36:18'),
(42,2,'DH-IPC-HFW5442TN-ASE','ACTIVE','2026-08-19 10:36:28'),
(43,2,'DH-IPC-HFW1230S1-S5','ACTIVE','2026-08-19 10:37:05'),
(44,2,'DHI-NVR5432-EI','ACTIVE','2026-08-19 10:37:15'),
(45,2,'DHI-NVR5432-4KS3/L','ACTIVE','2026-08-19 10:37:28'),
(46,2,'DHI-NVR5432-4KS3/L','ACTIVE','2026-08-19 10:37:58'),
(47,2,'DHI-5432-4KS3/L','ACTIVE','2026-08-19 11:06:39'),
(48,2,'DH-CS4006-4GT-60','ACTIVE','2026-08-19 11:07:14'),
(49,2,'DH-CHS-4106-4ET-60','ACTIVE','2026-08-19 11:31:03');

/*Table structure for table `setup_position` */

DROP TABLE IF EXISTS `setup_position`;

CREATE TABLE `setup_position` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

/*Data for the table `setup_position` */

insert  into `setup_position`(`id`,`name`,`status`,`date_created`) values 
(1,'CEO/PRESIDENT','ACTIVE','2026-08-19 09:43:47'),
(2,'ADMIN MANAGER','ACTIVE','2026-08-19 09:43:50'),
(3,'ADMIN STAFF','ACTIVE','2026-08-19 09:43:53'),
(4,'AUTHORIZED PERSONNEL','ACTIVE','2026-08-19 09:44:28'),
(5,'BUSINESS DEVELOPMENT OFFICER','ACTIVE','2026-08-19 09:44:40'),
(6,'TECHNICAL PERSONNEL','ACTIVE','2026-08-19 09:45:51');

/*Table structure for table `setup_project` */

DROP TABLE IF EXISTS `setup_project`;

CREATE TABLE `setup_project` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` text,
  `address` text,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `setup_project` */

/*Table structure for table `setup_supplier` */

DROP TABLE IF EXISTS `setup_supplier`;

CREATE TABLE `setup_supplier` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` text,
  `address` text,
  `tin_no` varchar(255) DEFAULT NULL,
  `contact_person` varchar(255) DEFAULT NULL,
  `contact_person_no` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `setup_supplier` */

/*Table structure for table `setup_unit_measure` */

DROP TABLE IF EXISTS `setup_unit_measure`;

CREATE TABLE `setup_unit_measure` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=9 DEFAULT CHARSET=latin1;

/*Data for the table `setup_unit_measure` */

insert  into `setup_unit_measure`(`id`,`name`,`status`,`date_created`) values 
(1,'PC/S','ACTIVE','2026-08-19 09:39:01'),
(2,'BOX/ES','ACTIVE','2026-08-19 09:39:07'),
(3,'PACK/S','ACTIVE','2026-08-19 09:39:12'),
(4,'SET','ACTIVE','2026-08-19 09:39:15'),
(5,'UNIT','ACTIVE','2026-08-19 09:39:19'),
(6,'LOT','ACTIVE','2026-08-19 09:39:21'),
(7,'METER/S','ACTIVE','2026-08-19 09:39:57'),
(8,'FEET/FOOT','ACTIVE','2026-08-19 09:40:04');

/*Table structure for table `setup_users` */

DROP TABLE IF EXISTS `setup_users`;

CREATE TABLE `setup_users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `name` text,
  `position_id` int DEFAULT '0',
  `type` varchar(20) DEFAULT 'USER',
  `status` varchar(20) DEFAULT 'ACTIVE',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;

/*Data for the table `setup_users` */

insert  into `setup_users`(`id`,`username`,`password`,`name`,`position_id`,`type`,`status`,`date_created`) values 
(1,'admin','p@ssw0rd','WEB ADMINISTRATOR',0,'ADMIN','ACTIVE','2026-08-19 09:18:52'),
(2,'skip','punisher','JON-ERIK SAYSON',2,'ADMIN','ACTIVE','2026-08-19 09:19:12'),
(3,'lark','p@ssw0rd','LARKE GELBOLINGO',1,'ADMIN','ACTIVE','2026-08-19 09:19:39'),
(4,'cyrus','p@ssw0rd','CYRUS RANQUE',3,'USER','ACTIVE','2026-08-19 09:23:01'),
(5,'nino','p@ssw0rd','NIÑO ALONZO',3,'USER','ACTIVE','2026-08-19 09:23:32');

/*Table structure for table `supplier_ledger` */

DROP TABLE IF EXISTS `supplier_ledger`;

CREATE TABLE `supplier_ledger` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int DEFAULT '0',
  `po_id` int DEFAULT '0',
  `debit` double DEFAULT '0',
  `credit` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `supplier_ledger` */

/*Table structure for table `outslip_main` */

DROP TABLE IF EXISTS `outslip_details`;
DROP TABLE IF EXISTS `outslip_main`;

CREATE TABLE `outslip_main` (
  `id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int unsigned DEFAULT '0',
  `customer_name` varchar(255) DEFAULT NULL,
  `outslip_no` varchar(255) DEFAULT NULL,
  `outslip_date` date DEFAULT NULL,
  `receiving_id` int unsigned DEFAULT '0',
  `branch_id` int unsigned DEFAULT '1',
  `prepared_by` int unsigned DEFAULT '0',
  `status` varchar(30) DEFAULT 'PENDING',
  `date_created` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `outslip_main` */

/*Table structure for table `outslip_details` */

CREATE TABLE `outslip_details` (
  `id` int NOT NULL AUTO_INCREMENT,
  `outslip_id` int unsigned DEFAULT '0',
  `item_id` int unsigned DEFAULT '0',
  `item_name` text,
  `qty` double DEFAULT '0',
  `price` double DEFAULT '0',
  `amount` double DEFAULT '0',
  `date_created` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `outslip_details` */

/*Table structure for table `gate_pass_main` */

DROP TABLE IF EXISTS `gate_pass_main`;

CREATE TABLE `gate_pass_main` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `outslip_id` int unsigned NOT NULL,
  `gate_pass_no` varchar(255) DEFAULT NULL,
  `vehicle_no` varchar(255) DEFAULT NULL,
  `driver_name` varchar(255) DEFAULT NULL,
  `plate_no` varchar(255) DEFAULT NULL,
  `destination` varchar(255) DEFAULT NULL,
  `remarks` text,
  `status` varchar(20) DEFAULT 'PENDING',
  `exit_at` datetime DEFAULT NULL,
  `prepared_by` int unsigned DEFAULT '0',
  `date_created` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `gate_pass_main_outslip_id_unique` (`outslip_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `gate_pass_main` */

/*Table structure for table `settings` */

DROP TABLE IF EXISTS `settings`;

CREATE TABLE `settings` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `company_name` varchar(191) NOT NULL,
  `company_address` text,
  `company_phone` varchar(191) DEFAULT NULL,
  `company_email` varchar(191) DEFAULT NULL,
  `user_name` varchar(191) DEFAULT NULL,
  `user_email` varchar(191) DEFAULT NULL,
  `date_format` varchar(191) NOT NULL DEFAULT 'F j, Y',
  `paper_size` varchar(191) NOT NULL DEFAULT 'A4',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

insert into `settings` (`id`,`company_name`,`company_address`,`company_phone`,`company_email`,`user_name`,`user_email`,`date_format`,`paper_size`,`created_at`,`updated_at`) values
(1,'RESPONSIVCODE TECHNOLOGY SOLUTIONS','RM301-E3 Medalle Bldg., Fuente Osmeña, Capitol Site, Cebu City 6000','09175734911','info@responsivcode.com','WEB ADMINISTRATOR','admin@responsivcode.com','F j, Y','A4',NOW(),NOW());

/*Table structure for table `ar_contracts` */

DROP TABLE IF EXISTS `ar_recurring_lines`;
DROP TABLE IF EXISTS `ar_contracts`;

CREATE TABLE `ar_contracts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `customer_id` int unsigned NOT NULL,
  `project_id` int unsigned DEFAULT NULL,
  `reference_text` varchar(500) DEFAULT NULL,
  `billing_type` varchar(20) NOT NULL,
  `contract_amount` decimal(15,2) DEFAULT NULL,
  `monthly_lump_amount` decimal(15,2) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `billing_months` smallint unsigned NOT NULL DEFAULT '12',
  `bill_day_of_month` tinyint unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ar_contracts_customer_id_index` (`customer_id`),
  KEY `ar_contracts_status_index` (`status`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ar_recurring_lines` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ar_contract_id` bigint unsigned NOT NULL,
  `section` varchar(30) DEFAULT NULL,
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  `account_label` varchar(255) NOT NULL,
  `account_number` varchar(64) DEFAULT NULL,
  `monthly_fee` decimal(15,2) NOT NULL DEFAULT '0.00',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ar_recurring_lines_ar_contract_id_index` (`ar_contract_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Table structure for table `api_tokens` */

DROP TABLE IF EXISTS `api_tokens`;

CREATE TABLE `api_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `setup_user_id` bigint unsigned NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT 'web',
  `token` varchar(64) NOT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `api_tokens_token_unique` (`token`),
  KEY `api_tokens_setup_user_id_index` (`setup_user_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*Data for the table `api_tokens` */

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
