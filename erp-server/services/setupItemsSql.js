const db = require('../config/db');
const { columnExists, ensureSchemaPatches } = require('../scripts/ensure-schema-patches');

let barcodeColumnChecked = false;
let setupItemsHasBarcode = false;

async function refreshSetupItemsBarcodeFlag(pool = db) {
  setupItemsHasBarcode = await columnExists(pool, 'setup_items', 'barcode');
  if (!setupItemsHasBarcode) {
    await ensureSchemaPatches(pool);
    setupItemsHasBarcode = await columnExists(pool, 'setup_items', 'barcode');
  }
  barcodeColumnChecked = true;
  return setupItemsHasBarcode;
}

async function setupItemsHasBarcodeColumn(pool = db) {
  if (!barcodeColumnChecked) {
    await refreshSetupItemsBarcodeFlag(pool);
  }
  return setupItemsHasBarcode;
}

/** Map of setup_items rows keyed by id — never fails if barcode column is missing. */
async function setupItemsMap(itemIds, pool = db) {
  const ids = [...new Set(itemIds.filter(Boolean))];
  if (ids.length === 0) return new Map();

  const hasBarcode = await setupItemsHasBarcodeColumn(pool);
  const select = hasBarcode
    ? 'SELECT id, item_name, barcode FROM setup_items WHERE id IN (?)'
    : 'SELECT id, item_name FROM setup_items WHERE id IN (?)';

  const [rows] = await pool.query(select, [ids]);
  return new Map(
    rows.map((r) => [
      r.id,
      hasBarcode ? r : { ...r, barcode: null },
    ])
  );
}

module.exports = {
  setupItemsMap,
  setupItemsHasBarcodeColumn,
  refreshSetupItemsBarcodeFlag,
};
