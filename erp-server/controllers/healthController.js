const db = require('../config/db');
const { setupItemsHasBarcodeColumn } = require('../services/setupItemsSql');

exports.show = async (req, res) => {
  let database = 'ok';
  let itemBarcodes = 'unknown';
  try {
    await db.query('SELECT 1');
    itemBarcodes = (await setupItemsHasBarcodeColumn()) ? 'ok' : 'missing';
  } catch {
    database = 'error';
  }

  return res.json({
    status: database === 'ok' && itemBarcodes === 'ok' ? 'ok' : 'degraded',
    app: 'ResponsivCode ERP',
    version: '0.2.0',
    phase: 8,
    database,
    itemBarcodes,
    api: 'node-mobile',
  });
};