/**
 * Idempotent schema patches for legacy rts_system imports (pre–Phase 4 / barcode).
 * Safe to run on every server start.
 */
async function columnExists(pool, table, column) {
  const [rows] = await pool.query(
    `SELECT COLUMN_NAME AS name
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column]
  );
  return rows.length > 0;
}

async function tableExists(pool, table) {
  const [rows] = await pool.query(
    `SELECT TABLE_NAME AS name
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [table]
  );
  return rows.length > 0;
}

async function ensureColumn(pool, table, column, alterSql) {
  if (!(await tableExists(pool, table))) {
    return false;
  }
  if (await columnExists(pool, table, column)) {
    return false;
  }
  await pool.query(`ALTER TABLE \`${table}\` ${alterSql}`);
  console.log(`Schema patch: ${table}.${column}`);
  return true;
}

async function ensureSetupItemsBarcode(pool) {
  const added = await ensureColumn(
    pool,
    'setup_items',
    'barcode',
    'ADD COLUMN barcode VARCHAR(64) NULL AFTER item_name'
  );
  if (added) {
    try {
      await pool.query('CREATE INDEX setup_items_barcode_idx ON setup_items (barcode)');
    } catch (err) {
      if (err.code !== 'ER_DUP_KEYNAME') throw err;
    }
  }
}

async function ensureApiTokensUserColumn(pool) {
  if (!(await tableExists(pool, 'api_tokens'))) return;

  if (await columnExists(pool, 'api_tokens', 'setup_user_id')) {
    return;
  }

  if (await columnExists(pool, 'api_tokens', 'user_id')) {
    await pool.query(
      'ALTER TABLE api_tokens CHANGE COLUMN user_id setup_user_id BIGINT UNSIGNED NOT NULL'
    );
    console.log('Schema patch: api_tokens.user_id → setup_user_id');
    return;
  }

  await pool.query(
    'ALTER TABLE api_tokens ADD COLUMN setup_user_id BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER id'
  );
  console.log('Schema patch: api_tokens.setup_user_id');
}

async function ensureFulfillmentColumns(pool) {
  await ensureColumn(
    pool,
    'gate_pass_main',
    'destination',
    'ADD COLUMN destination VARCHAR(255) NULL AFTER plate_no'
  );
  await ensureColumn(pool, 'gate_pass_main', 'exit_at', 'ADD COLUMN exit_at DATETIME NULL AFTER status');

  await ensureColumn(
    pool,
    'delivery_main',
    'outslip_id',
    'ADD COLUMN outslip_id INT UNSIGNED NOT NULL DEFAULT 0 AFTER id'
  );
  await ensureColumn(
    pool,
    'delivery_main',
    'dr_total',
    'ADD COLUMN dr_total DOUBLE NOT NULL DEFAULT 0 AFTER customer_name'
  );

  await ensureColumn(
    pool,
    'delivery_details',
    'price',
    'ADD COLUMN price DOUBLE NOT NULL DEFAULT 0 AFTER qty'
  );
  await ensureColumn(
    pool,
    'delivery_details',
    'amount',
    'ADD COLUMN amount DOUBLE NOT NULL DEFAULT 0 AFTER price'
  );
  await ensureColumn(
    pool,
    'delivery_details',
    'serial_no',
    'ADD COLUMN serial_no TEXT NULL AFTER amount'
  );

  await ensureColumn(
    pool,
    'outslip_details',
    'price',
    'ADD COLUMN price DOUBLE NOT NULL DEFAULT 0 AFTER qty'
  );
  await ensureColumn(
    pool,
    'outslip_details',
    'amount',
    'ADD COLUMN amount DOUBLE NOT NULL DEFAULT 0 AFTER price'
  );

  await ensureColumn(
    pool,
    'billing',
    'paid_amount',
    'ADD COLUMN paid_amount DOUBLE NOT NULL DEFAULT 0 AFTER billing_total'
  );

  await ensureColumn(
    pool,
    'purchase_main',
    'quotation_id',
    'ADD COLUMN quotation_id INT UNSIGNED NOT NULL DEFAULT 0 AFTER id'
  );
  await ensureColumn(
    pool,
    'receiving_main',
    'po_id',
    'ADD COLUMN po_id INT UNSIGNED NOT NULL DEFAULT 0 AFTER id'
  );
  await ensureColumn(
    pool,
    'receiving_main',
    'branch_id',
    'ADD COLUMN branch_id INT UNSIGNED NOT NULL DEFAULT 1 AFTER receiving_date'
  );
  await ensureColumn(
    pool,
    'receiving_main',
    'remarks',
    'ADD COLUMN remarks TEXT NULL AFTER branch_id'
  );
  await ensureColumn(
    pool,
    'inventory',
    'item_id',
    'ADD COLUMN item_id INT NOT NULL DEFAULT 0 AFTER branch_id'
  );

  await ensureColumn(
    pool,
    'receiving_details',
    'item_name',
    'ADD COLUMN item_name TEXT NULL AFTER item_id'
  );

  if (await tableExists(pool, 'ar_contracts')) {
    await ensureColumn(
      pool,
      'ar_contracts',
      'contract_no',
      'ADD COLUMN contract_no VARCHAR(255) NULL AFTER id'
    );
    await ensureColumn(
      pool,
      'ar_contracts',
      'monthly_fee',
      'ADD COLUMN monthly_fee DOUBLE NOT NULL DEFAULT 0'
    );
    await ensureColumn(
      pool,
      'ar_contracts',
      'billing_day',
      'ADD COLUMN billing_day TINYINT UNSIGNED NOT NULL DEFAULT 1'
    );
  }
}

async function ensureSchemaPatches(pool) {
  await ensureSetupItemsBarcode(pool);
  await ensureApiTokensUserColumn(pool);
  await ensureFulfillmentColumns(pool);
}

module.exports = { ensureSchemaPatches, columnExists, tableExists };
