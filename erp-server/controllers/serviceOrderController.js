// C:\ERP-System-main\erp-server\controllers\serviceOrderController.js
const moment = require('moment-timezone');
const db = require('../config/db');

function computeNextInvoiceNo(rows) {
  let max = 0;
  for (const r of rows) {
    const digits = String(r.invoice_no || '').replace(/\D+/g, '');
    const n = parseInt(digits, 10);
    if (!Number.isNaN(n) && n > max) max = n;
  }
  return String(max + 1).padStart(4, '0');
}

async function getNextInvoiceNo(conn = db) {
  const [rows] = await conn.query('SELECT invoice_no FROM service_orders');
  return computeNextInvoiceNo(rows);
}

function presentServiceOrder(row) {
  const saleTypeRaw = String(row.sale_type || 'charge').toLowerCase();
  const saleType = saleTypeRaw === 'cash' ? 'Cash Sales' : 'Charge Sales';

  return {
    id: row.invoice_no,
    dbId: String(row.id),
    invoiceNo: row.invoice_no,
    customerId: String(row.customer_id ?? ''),
    customerName: row.customer_name || '',
    projectId: row.project_id ? String(row.project_id) : null,
    projectName: row.project_name || '',
    description: row.description || '',
    date: row.transaction_date ? moment(row.transaction_date).format('YYYY-MM-DD') : '',
    displayDate: row.transaction_date ? moment(row.transaction_date).format('MMMM D, YYYY') : '',
    saleType,
    quantity: parseFloat(row.quantity || 0),
    unitCost: parseFloat(row.unit_price || 0),
    amount: parseFloat(row.amount || 0),
    status: String(row.status || 'pending').toLowerCase(),
  };
}

async function loadServiceOrder(idOrInvoice) {
  const [[row]] = await db.query(
    'SELECT * FROM service_orders WHERE id = ? OR invoice_no = ? LIMIT 1',
    [idOrInvoice, idOrInvoice]
  );
  return row || null;
}

exports.index = async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM service_orders
       WHERE LOWER(status) NOT IN ('rejected', 'void', 'inactive', 'cancelled')
       ORDER BY id DESC`
    );
    const nextInvoiceNo = await getNextInvoiceNo();

    return res.json({
      data: rows.map(presentServiceOrder),
      nextInvoiceNo,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.store = async (req, res) => {
  const { customerId, projectId, description, date, saleType, quantity, unitCost } = req.body;

  if (!customerId) {
    return res.status(422).json({ message: 'Customer is required.' });
  }

  const qty = parseFloat(quantity);
  const price = parseFloat(unitCost);
  if (Number.isNaN(qty) || qty <= 0) {
    return res.status(422).json({ message: 'Quantity must be greater than zero.' });
  }
  if (Number.isNaN(price) || price < 0) {
    return res.status(422).json({ message: 'Enter a valid unit cost.' });
  }

  try {
    const [[customer]] = await db.query(
      'SELECT * FROM setup_customer WHERE id = ? LIMIT 1',
      [customerId]
    );
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found.' });
    }

    let resolvedProjectId = '';
    let resolvedProjectName = '';
    if (projectId !== undefined && projectId !== null && String(projectId).trim() !== '') {
      const [[project]] = await db.query(
        'SELECT * FROM setup_project WHERE id = ? LIMIT 1',
        [projectId]
      );
      if (project) {
        resolvedProjectId = String(project.id);
        resolvedProjectName = project.name || '';
      }
    }

    const invoiceNo = await getNextInvoiceNo();
    const saleTypeDb = String(saleType || '').toLowerCase().includes('cash') ? 'cash' : 'charge';
    const amount = Math.round(qty * price * 100) / 100;
    const transDate = date ? moment(date).format('YYYY-MM-DD') : moment().format('YYYY-MM-DD');

    const [result] = await db.query(
      `INSERT INTO service_orders
       (invoice_no, customer_id, customer_name, customer_tin, customer_address,
        project_id, project_name, description, transaction_date, sale_type,
        quantity, unit_price, amount, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW(), NOW())`,
      [
        invoiceNo,
        String(customer.id),
        customer.name || '',
        customer.tin_no || '',
        customer.address || null,
        resolvedProjectId,
        resolvedProjectName,
        String(description || '').trim(),
        transDate,
        saleTypeDb,
        qty,
        price,
        amount,
      ]
    );

    const created = await loadServiceOrder(result.insertId);
    const nextInvoiceNo = await getNextInvoiceNo();

    return res.status(201).json({
      message: 'Service order saved.',
      data: presentServiceOrder(created),
      nextInvoiceNo,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.approve = async (req, res) => {
  const { id } = req.params;
  try {
    const row = await loadServiceOrder(id);
    if (!row) return res.status(404).json({ message: 'Service order not found.' });
    if (String(row.status).toLowerCase() !== 'pending') {
      return res.status(422).json({ message: 'Only pending service orders can be approved.' });
    }

    const actor = req.authUser?.name || req.authUser?.login || 'Admin';
    await db.query(
      `UPDATE service_orders
       SET status = 'approved', approved_by = ?, approved_at = CURDATE(), updated_at = NOW()
       WHERE id = ?`,
      [actor, row.id]
    );

    const updated = await loadServiceOrder(row.id);
    return res.json({
      message: 'Service order approved.',
      data: presentServiceOrder(updated),
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.reject = async (req, res) => {
  const { id } = req.params;
  try {
    const row = await loadServiceOrder(id);
    if (!row) return res.status(404).json({ message: 'Service order not found.' });
    if (String(row.status).toLowerCase() !== 'pending') {
      return res.status(422).json({ message: 'Only pending service orders can be rejected.' });
    }

    const actor = req.authUser?.name || req.authUser?.login || 'Admin';
    await db.query(
      `UPDATE service_orders
       SET status = 'rejected', rejected_by = ?, rejected_at = CURDATE(), updated_at = NOW()
       WHERE id = ?`,
      [actor, row.id]
    );

    const updated = await loadServiceOrder(row.id);
    return res.json({
      message: 'Service order rejected.',
      data: presentServiceOrder(updated),
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

exports.voidOrder = async (req, res) => {
  const { id } = req.params;
  try {
    const row = await loadServiceOrder(id);
    if (!row) return res.status(404).json({ message: 'Service order not found.' });

    await db.query(
      `UPDATE service_orders
       SET status = 'void', updated_at = NOW()
       WHERE id = ?`,
      [row.id]
    );

    const updated = await loadServiceOrder(row.id);
    return res.json({
      message: 'Service order voided.',
      data: presentServiceOrder(updated),
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};