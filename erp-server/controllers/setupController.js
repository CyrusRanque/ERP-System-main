const db = require('../config/db');
const bcrypt = require('bcryptjs');
const setupPresenter = require('../services/setupPresenter');
const { quantitiesByItemId } = require('../services/inventoryStock');
const { setupItemsHasBarcodeColumn } = require('../services/setupItemsSql');

const RESOURCE_TABLE_MAP = {
  companies: { table: 'setup_company', prefix: 'COM' },
  branches: { table: 'setup_branch', prefix: 'BR' },
  users: { table: 'setup_users', prefix: 'USR' },
  positions: { table: 'setup_position', prefix: 'POS' },
  projects: { table: 'setup_project', prefix: 'PRJ' },
  categories: { table: 'setup_category', prefix: 'CAT' },
  brands: { table: 'setup_brand', prefix: 'BRD' },
  models: { table: 'setup_model', prefix: 'MOD' },
  units: { table: 'setup_unit_measure', prefix: 'UNT' },
  items: { table: 'setup_items', prefix: 'ITM' },
  suppliers: { table: 'setup_supplier', prefix: 'SUP' },
  customers: { table: 'setup_customer', prefix: 'CUST' },
};

function toIntOrDefault(value, fallback = null) {
  if (value === undefined || value === null || String(value).trim() === '') {
    return fallback;
  }
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? fallback : n;
}

function normalizeStatus(value, fallback = 'ACTIVE') {
  if (value === undefined || value === null || String(value).trim() === '') {
    return fallback;
  }
  return String(value).trim().toUpperCase() === 'INACTIVE' ? 'INACTIVE' : 'ACTIVE';
}

async function mapSetupPayload(resource, body, { isCreate = false } = {}) {
  const b = body || {};
  const mapped = {};

  switch (resource) {
    case 'items': {
      const name = b.item_name ?? b.itemName ?? b.name;
      if (name !== undefined) mapped.item_name = String(name).trim();
      const brandId = b.brand_id ?? b.brandId;
      if (brandId !== undefined) mapped.brand_id = toIntOrDefault(brandId, 0);
      const modelId = b.model_id ?? b.modelId;
      if (modelId !== undefined) mapped.model_id = toIntOrDefault(modelId, 0);
      const unitId =
        b.unit_measure_id ??
        b.unitMeasureId ??
        b.unit_of_measure_id ??
        b.unitOfMeasureId ??
        b.unitId ??
        b.unit_id;
      if (unitId !== undefined) mapped.unit_measure_id = toIntOrDefault(unitId, null);
      if (b.barcode !== undefined && (await setupItemsHasBarcodeColumn())) {
        const code = String(b.barcode ?? '').trim();
        mapped.barcode = code === '' ? null : code;
      }
      break;
    }
    case 'customers': {
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      if (b.address !== undefined) mapped.address = b.address ?? null;
      const tin = b.tin_no ?? b.tinNo ?? b.tin;
      if (tin !== undefined) mapped.tin_no = tin ?? null;
      if (b.terms !== undefined) mapped.terms = toIntOrDefault(b.terms, null);
      const termsType = b.terms_type ?? b.termsType;
      if (termsType !== undefined) mapped.terms_type = termsType || 'IN DAYS';
      break;
    }
    case 'suppliers': {
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      if (b.address !== undefined) mapped.address = b.address ?? null;
      const tin = b.tin_no ?? b.tinNo ?? b.tin;
      if (tin !== undefined) mapped.tin_no = tin ?? null;
      const contact = b.contact_person ?? b.contactPerson ?? b.contact;
      if (contact !== undefined) mapped.contact_person = contact ?? null;
      const phone = b.contact_person_no ?? b.contactPersonNo ?? b.phone;
      if (phone !== undefined) mapped.contact_person_no = phone ?? null;
      break;
    }
    case 'projects': {
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      const address = b.address ?? b.location;
      if (address !== undefined) mapped.address = address ?? null;
      break;
    }
    case 'models': {
      const brandId = b.brand_id ?? b.brandId;
      if (brandId !== undefined) mapped.brand_id = toIntOrDefault(brandId, 0);
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      break;
    }
    case 'branches': {
      const companyId = b.company_id ?? b.companyId;
      if (companyId !== undefined) mapped.company_id = toIntOrDefault(companyId, 0);
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      break;
    }
    case 'companies': {
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      if (b.address !== undefined) mapped.address = b.address ?? null;
      const contactNo = b.contact_no ?? b.contactNo ?? b.phone;
      if (contactNo !== undefined) mapped.contact_no = contactNo ?? null;
      const tin = b.tin_no ?? b.tinNo ?? b.tin;
      if (tin !== undefined) mapped.tin_no = tin ?? null;
      break;
    }
    case 'users': {
      if (b.username !== undefined) mapped.username = String(b.username).trim();
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      const posId = b.position_id ?? b.positionId;
      if (posId !== undefined) mapped.position_id = toIntOrDefault(posId, 0);
      const type = b.type ?? b.role;
      if (type !== undefined) mapped.type = String(type).toUpperCase();
      if (b.password) mapped.password = bcrypt.hashSync(b.password, 10);
      break;
    }
    default: {
      if (b.name !== undefined) mapped.name = String(b.name).trim();
      break;
    }
  }

  if (isCreate || b.status !== undefined) {
    mapped.status = normalizeStatus(b.status, 'ACTIVE');
  }

  return mapped;
}

exports.index = async (req, res) => {
  const { resource } = req.params;
  const config = RESOURCE_TABLE_MAP[resource];
  if (!config) return res.status(404).json({ message: 'Setup resource not found.' });

  try {
    if (resource === 'items') {
      const [rows] = await db.query(
        `SELECT i.*, b.name AS brand_name, m.name AS model_name, u.name AS unit_name
         FROM setup_items i
         LEFT JOIN setup_brand b ON i.brand_id = b.id
         LEFT JOIN setup_model m ON i.model_id = m.id
         LEFT JOIN setup_unit_measure u ON i.unit_measure_id = u.id
         ORDER BY i.id ASC`
      );
      const stockByItemId = await quantitiesByItemId();
      return res.json({ data: setupPresenter.collection('items', rows, stockByItemId) });
    }

    const [rows] = await db.query(`SELECT * FROM ${config.table} ORDER BY id ASC`);
    return res.json({ data: setupPresenter.collection(resource, rows) });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.store = async (req, res) => {
  const { resource } = req.params;
  const config = RESOURCE_TABLE_MAP[resource];
  if (!config) return res.status(404).json({ message: 'Setup resource not found.' });

  try {
    const payload = await mapSetupPayload(resource, req.body, { isCreate: true });
    if (resource === 'items' && !payload.item_name) {
      return res.status(422).json({ message: 'Item name is required.' });
    }

    const keys = Object.keys(payload);
    if (keys.length === 0) {
      return res.status(422).json({ message: 'No valid fields provided.' });
    }

    const values = Object.values(payload);
    const columns = keys.map((k) => `\`${k}\``).join(', ');
    const placeholders = keys.map(() => '?').join(', ');

    const [result] = await db.query(
      `INSERT INTO ${config.table} (${columns}) VALUES (${placeholders})`,
      values
    );

    if (resource === 'items') {
      const [[row]] = await db.query(
        `SELECT i.*, b.name AS brand_name, m.name AS model_name, u.name AS unit_name
         FROM setup_items i
         LEFT JOIN setup_brand b ON i.brand_id = b.id
         LEFT JOIN setup_model m ON i.model_id = m.id
         LEFT JOIN setup_unit_measure u ON i.unit_measure_id = u.id
         WHERE i.id = ?`,
        [result.insertId]
      );
      return res.status(201).json({
        message: 'Record created successfully.',
        data: setupPresenter.item(row, new Map()),
      });
    }

    const [[row]] = await db.query(`SELECT * FROM ${config.table} WHERE id = ?`, [result.insertId]);
    return res.status(201).json({
      message: 'Record created successfully.',
      data: setupPresenter.present(resource, row),
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.update = async (req, res) => {
  const { resource, id } = req.params;
  const config = RESOURCE_TABLE_MAP[resource];
  if (!config) return res.status(404).json({ message: 'Setup resource not found.' });

  try {
    const payload = await mapSetupPayload(resource, req.body, { isCreate: false });
    const keys = Object.keys(payload);
    if (keys.length === 0) {
      return res.status(422).json({ message: 'No valid fields provided.' });
    }

    const updates = keys.map((k) => `\`${k}\` = ?`).join(', ');
    const values = [...Object.values(payload), id];

    await db.query(`UPDATE ${config.table} SET ${updates} WHERE id = ?`, values);
    return res.json({ message: 'Record updated successfully.' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.destroy = async (req, res) => {
  const { resource, id } = req.params;
  const config = RESOURCE_TABLE_MAP[resource];
  if (!config) return res.status(404).json({ message: 'Setup resource not found.' });

  try {
    await db.query(`UPDATE ${config.table} SET status = 'Inactive' WHERE id = ?`, [id]);
    return res.json({ message: 'Record deactivated successfully.' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.showItemByBarcode = async (req, res) => {
  const { barcode } = req.params;
  try {
    const hasBarcode = await setupItemsHasBarcodeColumn();
    if (!hasBarcode) {
      return res.status(503).json({
        message:
          'Item barcode column missing in MySQL. Restart erp-server (npm start) on your PC to apply schema patches.',
      });
    }

    const [rows] = await db.query(
      `SELECT i.*, b.name AS brand_name, u.name AS unit_name
       FROM setup_items i
       LEFT JOIN setup_brand b ON i.brand_id = b.id
       LEFT JOIN setup_unit_measure u ON i.unit_measure_id = u.id
       WHERE LOWER(TRIM(i.barcode)) = ? AND UPPER(TRIM(i.status)) = 'ACTIVE' LIMIT 1`,
      [barcode.trim().toLowerCase()]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'No item found for this barcode.' });
    }

    const item = rows[0];
    return res.json({
      data: {
        id: String(item.id),
        name: item.item_name,
        code: item.barcode,
        brand: item.brand_name || '',
        unit: item.unit_name || 'UNITS',
      },
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};