import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

const _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);

/// Office **Expenses Ledger** — supplier ledger + project expenses ledger.
class ExpensesLedgerPage extends StatefulWidget {
  const ExpensesLedgerPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ExpensesLedgerPage> createState() => _ExpensesLedgerPageState();
}

class _ExpensesLedgerPageState extends State<ExpensesLedgerPage> {
  bool _loadingSetup = true;
  bool _loadingSupplierLedger = false;
  bool _loadingProjectLedger = false;
  String? _error;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _projects = [];
  String? _supplierId;
  String? _projectId;
  Map<String, dynamic>? _supplierAccount;
  Map<String, dynamic>? _projectAccount;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
    });
    try {
      await widget.api.ensureConfigured();
      final results = await Future.wait([
        widget.api.getList('/setup/suppliers'),
        widget.api.getList('/setup/projects'),
      ]);
      final suppliers = results[0].cast<Map<String, dynamic>>();
      final projects = results[1].cast<Map<String, dynamic>>();
      await Future.wait([
        OfflineCache.saveList(OfflineCache.suppliers, suppliers),
        OfflineCache.saveList(OfflineCache.projects, projects),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers.where((s) => s['status'] != 'Inactive').toList();
        _projects = projects.where((p) => p['status'] != 'Inactive').toList();
        _loadingSetup = false;
      });
    } catch (error) {
      final cachedSuppliers = await OfflineCache.loadList(OfflineCache.suppliers);
      final cachedProjects = await OfflineCache.loadList(OfflineCache.projects);
      if (!mounted) return;
      setState(() {
        _suppliers = cachedSuppliers.rows.where((s) => s['status'] != 'Inactive').toList();
        _projects = cachedProjects.rows;
        _loadingSetup = false;
        if (_suppliers.isEmpty && _projects.isEmpty) {
          _error = friendlyApiError(error);
        }
      });
    }
  }

  Future<void> _loadSupplierLedger() async {
    final supplierId = _supplierId;
    if (supplierId == null || supplierId.isEmpty) {
      setState(() => _supplierAccount = null);
      return;
    }

    setState(() => _loadingSupplierLedger = true);
    try {
      final account = await widget.api.getData('/reports/supplier-ledger', query: {'supplierId': supplierId});
      if (!mounted) return;
      setState(() {
        _supplierAccount = account;
        _loadingSupplierLedger = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyApiError(error);
        _loadingSupplierLedger = false;
      });
    }
  }

  Future<void> _loadProjectLedger() async {
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() => _projectAccount = null);
      return;
    }

    setState(() => _loadingProjectLedger = true);
    try {
      final account = await widget.api.getData('/reports/expenses-ledger', query: {'projectId': projectId});
      if (!mounted) return;
      setState(() {
        _projectAccount = account;
        _loadingProjectLedger = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyApiError(error);
        _loadingProjectLedger = false;
      });
    }
  }

  List<Map<String, dynamic>> _ledgerRows(Map<String, dynamic>? account) {
    if (account == null) return [];
    return (account['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _ledgerTable({
    required List<Map<String, dynamic>> rows,
    required bool loading,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
          columnSpacing: 16,
          horizontalMargin: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          columns: const [
            DataColumn(label: Text('Transaction Date', style: _headerStyle)),
            DataColumn(label: Text('Transaction No', style: _headerStyle)),
            DataColumn(label: Text('Debit', style: _headerStyle), numeric: true),
            DataColumn(label: Text('Credit', style: _headerStyle), numeric: true),
            DataColumn(label: Text('Balance', style: _headerStyle), numeric: true),
          ],
          rows: rows.isEmpty
              ? [
                  const DataRow(
                    cells: [
                      DataCell(Text('—')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ],
                  ),
                ]
              : rows.map((row) {
                  final debit = (row['debit'] as num?)?.toDouble() ?? 0;
                  final credit = (row['credit'] as num?)?.toDouble() ?? 0;
                  final balance = (row['balance'] as num?)?.toDouble();
                  return DataRow(
                    cells: [
                      DataCell(Text(row['transactionDate']?.toString() ?? row['displayDate']?.toString() ?? '—')),
                      DataCell(Text(row['transNo']?.toString() ?? row['ref']?.toString() ?? '—')),
                      DataCell(Text(debit > 0 ? fieldFormatMoney(debit) : '')),
                      DataCell(Text(credit > 0 ? fieldFormatMoney(credit) : '')),
                      DataCell(
                        Text(
                          balance != null ? fieldFormatMoney(balance) : '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }).toList(),
        ),
      ),
    );
  }

  Widget _supplierSection() {
    final rows = _ledgerRows(_supplierAccount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('sup_$_supplierId'),
              isExpanded: true,
              initialValue: _supplierId,
              decoration: const InputDecoration(
                labelText: 'Supplier',
                hintText: 'Select Supplier...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Select Supplier...')),
                ..._suppliers.map(
                  (s) => DropdownMenuItem(
                    value: s['id']?.toString(),
                    child: Text(s['name']?.toString() ?? 'Supplier', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _supplierId = value);
                _loadSupplierLedger();
              },
            ),
            const SizedBox(height: 16),
            const Text('Supplier Ledger', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _ledgerTable(rows: rows, loading: _loadingSupplierLedger),
          ],
        ),
      ),
    );
  }

  Widget _projectSection() {
    final rows = _ledgerRows(_projectAccount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('prj_$_projectId'),
              isExpanded: true,
              initialValue: _projectId,
              decoration: const InputDecoration(
                labelText: 'Project',
                hintText: 'Select Project...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Select Project...')),
                ..._projects.map(
                  (p) => DropdownMenuItem(
                    value: p['id']?.toString(),
                    child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _projectId = value);
                _loadProjectLedger();
              },
            ),
            const SizedBox(height: 16),
            const Text('Expenses Ledger', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _ledgerTable(rows: rows, loading: _loadingProjectLedger),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSetup) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadSetup,
      color: AppTheme.maroon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 720;
          final body = sideBySide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _supplierSection()),
                    const SizedBox(width: 12),
                    Expanded(child: _projectSection()),
                  ],
                )
              : Column(
                  children: [
                    _supplierSection(),
                    const SizedBox(height: 12),
                    _projectSection(),
                  ],
                );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              if (_error != null) FieldErrorBanner(message: _error!, onRetry: _loadSetup),
              const Text('Expenses Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              body,
            ],
          );
        },
      ),
    );
  }
}