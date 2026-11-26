import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../screens/accomplishments_page.dart';
import '../screens/ar_aging_page.dart';
import '../screens/ar_entry_page.dart';
import '../screens/billing_page.dart';
import '../screens/customer_ledger_page.dart';
import '../screens/service_orders_page.dart';
import '../screens/deliveries_page.dart';
import '../screens/outslips_page.dart';
import '../screens/purchase_orders_page.dart';
import '../screens/quotations_page.dart';
import '../screens/receivables_hub_page.dart';
import '../screens/expenses_hub_page.dart';
import '../screens/receivings_page.dart';
import '../screens/receivables_soa_page.dart';
import '../screens/petty_cash_page.dart';
import '../screens/liquidation_page.dart';
import '../screens/ap_entry_page.dart';
import '../screens/disbursement_page.dart';
import '../screens/expenses_ledger_page.dart';
import '../screens/ap_aging_page.dart';

/// Matches the web sidebar **TRANSACTIONS** section only (not Setup or Reports).
enum MobileModule {
  home,
  quotations,
  purchaseOrders,
  receiving,
  outslips,
  deliveries,
  serviceOrders,
  receivables,
  arEntry,
  billing,
  receivablesSoa,
  customerLedger,
  arAging,
  expenses,
  pettyCash,
  liquidation,
  apEntry,
  disbursement,
  expensesLedger,
  apAging,
  accomplishments,
}

class MobileModuleInfo {
  const MobileModuleInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gridLabel,
    this.navLabel,
  });

  final MobileModule id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Short label under the dashboard icon grid.
  final String gridLabel;

  /// Longer label when needed (defaults to [title]).
  final String? navLabel;

  String get effectiveNavLabel => navLabel ?? title;
}

const receivablesChildModuleInfos = <MobileModuleInfo>[
  MobileModuleInfo(
    id: MobileModule.arEntry,
    title: 'AR Entry',
    subtitle: 'Invoice, deductions, contract',
    icon: Icons.edit_note_outlined,
    gridLabel: 'AR Entry',
    navLabel: 'AR Entry',
  ),
  MobileModuleInfo(
    id: MobileModule.receivablesSoa,
    title: 'Statement of Account',
    subtitle: 'Posted receivables ledger',
    icon: Icons.account_balance_wallet_outlined,
    gridLabel: 'SOA',
    navLabel: 'Statement of Account',
  ),
  MobileModuleInfo(
    id: MobileModule.billing,
    title: 'Received Payment',
    subtitle: 'Record customer payments',
    icon: Icons.payments_outlined,
    gridLabel: 'Payment',
    navLabel: 'Received Payment',
  ),
  MobileModuleInfo(
    id: MobileModule.customerLedger,
    title: 'Customer Ledger',
    subtitle: 'Debit and credit history',
    icon: Icons.menu_book_outlined,
    gridLabel: 'Ledger',
    navLabel: 'Customer Ledger',
  ),
  MobileModuleInfo(
    id: MobileModule.arAging,
    title: 'AR Aging',
    subtitle: 'Open receivables by age',
    icon: Icons.hourglass_top_outlined,
    gridLabel: 'Aging',
    navLabel: 'AR Aging',
  ),
];

const expensesChildModuleInfos = <MobileModuleInfo>[
  MobileModuleInfo(
    id: MobileModule.pettyCash,
    title: 'Petty Cash',
    subtitle: 'Small cash vouchers',
    icon: Icons.savings_outlined,
    gridLabel: 'Petty Cash',
    navLabel: 'Petty Cash',
  ),
  MobileModuleInfo(
    id: MobileModule.liquidation,
    title: 'Liquidation',
    subtitle: 'Liquidate advances',
    icon: Icons.fact_check_outlined,
    gridLabel: 'Liquidation',
    navLabel: 'Liquidation',
  ),
  MobileModuleInfo(
    id: MobileModule.apEntry,
    title: 'AP Entry',
    subtitle: 'Supplier invoice & contract',
    icon: Icons.edit_note_outlined,
    gridLabel: 'AP Entry',
    navLabel: 'AP Entry',
  ),
  MobileModuleInfo(
    id: MobileModule.disbursement,
    title: 'Disbursement',
    subtitle: 'Release payments',
    icon: Icons.payments_outlined,
    gridLabel: 'Disbursement',
    navLabel: 'Disbursement',
  ),
  MobileModuleInfo(
    id: MobileModule.expensesLedger,
    title: 'Expenses Ledger',
    subtitle: 'Supplier activity',
    icon: Icons.menu_book_outlined,
    gridLabel: 'Ledger',
    navLabel: 'Expenses Ledger',
  ),
  MobileModuleInfo(
    id: MobileModule.apAging,
    title: 'AP Aging',
    subtitle: 'Open payables by age',
    icon: Icons.hourglass_top_outlined,
    gridLabel: 'Aging',
    navLabel: 'AP Aging',
  ),
];

const expensesHubModuleInfo = MobileModuleInfo(
  id: MobileModule.expenses,
  title: 'Expenses',
  subtitle: 'Petty cash, AP, ledger, aging',
  icon: Icons.shopping_cart_outlined,
  gridLabel: 'Expenses',
);

const _transactionDashboardModules = <MobileModuleInfo>[
  MobileModuleInfo(
    id: MobileModule.quotations,
    title: 'Quotations',
    subtitle: 'Approve and convert to PO',
    icon: Icons.request_quote_outlined,
    gridLabel: 'Quotations',
  ),
  MobileModuleInfo(
    id: MobileModule.purchaseOrders,
    title: 'Purchase Orders',
    subtitle: 'Receive items from suppliers',
    icon: Icons.shopping_cart_outlined,
    gridLabel: 'PO',
  ),
  MobileModuleInfo(
    id: MobileModule.receiving,
    title: 'Receiving',
    subtitle: 'Confirm warehouse intake',
    icon: Icons.inventory_2_outlined,
    gridLabel: 'Receive',
  ),
  MobileModuleInfo(
    id: MobileModule.outslips,
    title: 'Outslips',
    subtitle: 'Approve and dispatch stock',
    icon: Icons.outbox_outlined,
    gridLabel: 'Outslip',
  ),
  MobileModuleInfo(
    id: MobileModule.deliveries,
    title: 'Delivery Receipts',
    subtitle: 'Track delivery status',
    icon: Icons.local_shipping_outlined,
    gridLabel: 'Delivery',
  ),
  MobileModuleInfo(
    id: MobileModule.serviceOrders,
    title: 'Service Order',
    subtitle: 'Charge sales & services',
    icon: Icons.build_circle_outlined,
    gridLabel: 'Service',
  ),
];

const receivablesHubModuleInfo = MobileModuleInfo(
  id: MobileModule.receivables,
  title: 'Receivables',
  subtitle: 'AR entry, payments, ledger, and aging',
  icon: Icons.view_in_ar_outlined,
  gridLabel: 'Receivables',
);

const accomplishmentsModuleInfo = MobileModuleInfo(
  id: MobileModule.accomplishments,
  title: 'Accomplishments',
  subtitle: 'Field photo reports',
  icon: Icons.photo_camera_outlined,
  gridLabel: 'Reports',
);

/// Tiles on the home **TRANSACTIONS** card (Receivables children open inside the hub).
List<MobileModuleInfo> get mobileDashboardModules => [
      ..._transactionDashboardModules,
      receivablesHubModuleInfo,
      expensesHubModuleInfo,
      accomplishmentsModuleInfo,
    ];

/// Lookup for titles / icons (dashboard + hub children).
List<MobileModuleInfo> get allMobileModuleInfos => [
      ...mobileDashboardModules,
      ...receivablesChildModuleInfos,
      ...expensesChildModuleInfos,
    ];

bool isReceivablesChildModule(MobileModule module) {
  return receivablesChildModuleInfos.any((item) => item.id == module);
}

bool isReceivablesHubOnlyChild(MobileModule module) {
  return isReceivablesChildModule(module);
}

bool isExpensesChildModule(MobileModule module) {
  return expensesChildModuleInfos.any((item) => item.id == module);
}

bool isExpensesHubOnlyChild(MobileModule module) {
  return isExpensesChildModule(module);
}

MobileModuleInfo mobileModuleInfo(MobileModule module) {
  return allMobileModuleInfos.firstWhere((item) => item.id == module);
}

Widget buildMobileModulePage(
  MobileModule module,
  ApiClient api, {
  Map<MobileModule, int> counts = const {},
}) {
  switch (module) {
    case MobileModule.home:
      throw ArgumentError('Home is not a module page');
    case MobileModule.quotations:
      return QuotationsPage(api: api);
    case MobileModule.purchaseOrders:
      return PurchaseOrdersPage(api: api);
    case MobileModule.receiving:
      return ReceivingsPage(api: api);
    case MobileModule.outslips:
      return OutslipsPage(api: api);
    case MobileModule.deliveries:
      return DeliveriesPage(api: api);
    case MobileModule.serviceOrders:
      return ServiceOrdersPage(api: api);
    case MobileModule.receivables:
      return ReceivablesHubPage(counts: counts);
    case MobileModule.arEntry:
      return ArEntryPage(api: api);
    case MobileModule.billing:
      return BillingPage(api: api);
    case MobileModule.receivablesSoa:
      return ReceivablesSoaPage(api: api);
    case MobileModule.customerLedger:
      return CustomerLedgerPage(api: api);
    case MobileModule.arAging:
      return ArAgingPage(api: api);
    case MobileModule.expenses:
      return ExpensesHubPage(counts: counts);
    case MobileModule.pettyCash:
      return PettyCashPage(api: api);
    case MobileModule.liquidation:
      return LiquidationPage(api: api);
    case MobileModule.apEntry:
      return ApEntryPage(api: api);
    case MobileModule.disbursement:
      return DisbursementPage(api: api);
    case MobileModule.expensesLedger:
      return ExpensesLedgerPage(api: api);
    case MobileModule.apAging:
      return ApAgingPage(api: api);
    case MobileModule.accomplishments:
      return AccomplishmentsPage(api: api);
  }
}

String mobileModuleTitle(MobileModule module) {
  return mobileModuleInfo(module).title;
}