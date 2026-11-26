PRIMARY IMPORT (your SQLyog schema + mobile API)
  C:\databases-mobile\rts_updated.sql  (run build-rts_updated.bat to rebuild)
  C:\databases-mobile\rts_mobile_demo_data.sql  — customers, barcodes, QTN→DR demo
  C:\databases-mobile\README.txt

Also in repo:
  database/rts_mobile_schema_align.sql  — idempotent column/table fixes (same as in rts_updated.sql)

WHEN TO USE
  Fresh WAMP install, or reset after a bad/partial import.
  WARNING: Import DROPs tables — back up live rts_system first if you have real data.

HOW TO IMPORT
  phpMyAdmin → Import → mobile_rts_system.sql
  OR: mysql -uroot < mobile_rts_system.sql

AFTER IMPORT
  1. erp-server/.env  DB_NAME=rts_system
  2. npm start  (in erp-server)
  3. Phone: 192.168.x.x:8000 → Save & connect → pull to refresh
  4. Login: admin / p@ssw0rd

OPTIONAL DEMO DATA
  mobile_demo_seed.sql  — Blake, Sean Paul, Naruto, 2× Mamarazi Co. customers, pending QTNs, DR for scanner
  C:\erp-system\database\demo_reference_seed.sql  (older office demo)

VERIFY
  http://YOUR_PC_IP:8000/api/mobile/health
  Must show: "itemBarcodes":"ok", "api":"node-mobile"
