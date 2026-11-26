/**
 * MySQL objects the Flutter field app + erp-server expect (RTS / Laravel legacy DB).
 * Reference dump: C:\\databases-mobile\\rts_updated.sql (import into MySQL rts_system)
 */

/** All transaction + auth tables that must exist before mobile workflows run. */
const MOBILE_REQUIRED_TABLES = [
  'quotation_main',
  'quotation_details',
  'purchase_main',
  'purchase_details',
  'receiving_main',
  'receiving_details',
  'outslip_main',
  'outslip_details',
  'gate_pass_main',
  'delivery_main',
  'delivery_details',
  'billing',
  'billing_payments',
  'inventory',
  'setup_users',
  'api_tokens',
  'settings',
  'setup_items',
  'setup_customer',
  'setup_supplier',
  'setup_project',
  'setup_brand',
  'setup_model',
  'setup_unit_measure',
  'accomplishment_main',
  'accomplishment_details',
  'customer_ledger',
  'supplier_ledger',
  'ar_contracts',
  'ar_recurring_lines',
];

/** Columns verified after idempotent patches (table, column). */
const MOBILE_REQUIRED_COLUMNS = [
  ['setup_items', 'barcode'],
  ['api_tokens', 'setup_user_id'],
  ['gate_pass_main', 'destination'],
  ['gate_pass_main', 'exit_at'],
  ['delivery_main', 'outslip_id'],
  ['delivery_main', 'dr_total'],
  ['delivery_details', 'price'],
  ['delivery_details', 'amount'],
  ['delivery_details', 'serial_no'],
  ['outslip_details', 'price'],
  ['outslip_details', 'amount'],
  ['billing', 'paid_amount'],
  ['purchase_main', 'quotation_id'],
  ['receiving_main', 'po_id'],
  ['receiving_main', 'branch_id'],
  ['inventory', 'item_id'],
  ['receiving_details', 'item_name'],
];

module.exports = { MOBILE_REQUIRED_TABLES, MOBILE_REQUIRED_COLUMNS };
