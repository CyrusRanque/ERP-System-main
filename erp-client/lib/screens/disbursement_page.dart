// C:\ERP-System-main\erp-client\lib\screens\disbursement_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

InputDecoration _disbField(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

const _paymentMethods = ['CASH', 'CHECK', 'BANK'];

/// Office **Disbursement** — pay open AP, post payment, browse history.
class DisbursementPage extends StatefulWidget {
  const DisbursementPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<DisbursementPage> createState() => _DisbursementPageState();
}

class _DisbursementPageState extends State<DisbursementPage> {
  bool _loadingPayables = true;
  bool _loadingHistory = true;
  bool _loadingBranches = true;
  bool _fromCache = false;
  bool _saving = false;
  String? _error;
  String? _offlineLabel;

  List<Map<String, dynamic>> _payables = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _branches = [];

  Map<String, dynamic>? _selectedPayable;
  String? _branchId;
  String _paymentMethod = 'CASH';
  DateTime _transactionDate = DateTime.now();
  DateTime _referenceDate = DateTime.now();
  DateTime? _historyFrom;
  DateTime? _historyTo;

  final _payableSearchController = TextEditingController();
  final _historySearchController = TextEditingController();
  final _referenceNoController = TextEditingController();
  final _checkNoController = TextEditingController();
  final _discountController = TextEditingController(text: '0.00');
  final _totalController = TextEditingController(text: '0.00');
  final _dueController = TextEditingController(text: '0.00');
  final _amountPaidController = TextEditingController(text: '0.00');
  final _changeController = TextEditingController(text: '0.00');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _historyFrom = DateTime(now.year, now.month, 1);
    _historyTo = now;
    _discountController.addListener(_syncTotals);
    _amountPaidController.addListener(_syncTotals);
    _bootstrap();
  }

  @override
  void dispose() {
    _payableSearchController.dispose();
    _historySearchController.dispose();
    _referenceNoController.dispose();
    _checkNoController.dispose();
    _discountController.dispose();
    _totalController.dispose();
    _dueController.dispose();
    _amountPaidController.dispose();
    _changeController.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  void _syncTotals() {
    final total = _parse(_totalController);
    final discount = _parse(_discountController);
    final due = fieldRoundMoney((total - discount).clamp(0, double.infinity));
    final paid = _parse(_amountPaidController);
    final change = fieldRoundMoney((paid - due).clamp(0, double.infinity));
    _dueController.text = due.toStringAsFixed(2);
    _changeController.text = change.toStringAsFixed(2);
  }

  void _selectPayable(Map<String, dynamic> row) {
    final balance = (row['balance'] as num?)?.toDouble() ??
        (((row['amount'] as num?)?.toDouble() ?? 0) - ((row['paidAmount'] as num?)?.toDouble() ?? 0));
    setState(() {
      _selectedPayable = row;
      _totalController.text = balance.toStringAsFixed(2);
      _discountController.text = '0.00';
      _amountPaidController.text = balance.toStringAsFixed(2);
      _referenceNoController.clear();
      _checkNoController.clear();
      _paymentMethod = 'CASH';
      _transactionDate = DateTime.now();
      _referenceDate = DateTime.now();
    });
    _syncTotals();
  }

  void _clearSelection() {
    setState(() {
      _selectedPayable = null;
      _totalController.text = '0.00';
      _discountController.text = '0.00';
      _dueController.text = '0.00';
      _amountPaidController.text = '0.00';
      _changeController.text = '0.00';
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadBranches(), _loadPayables(), _loadHistory()]);
  }

  Future<void> _loadBranches() async {
    setState(() => _loadingBranches = true);
    try {
      await widget.api.ensureConfigured();
      final data = await widget.api.getList('/setup/branches');
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.branches, rows);
      if (!mounted) return;
      setState(() {
        _branches = rows.where((b) => b['status'] != 'Inactive').toList();
        _branchId ??= _branches.isNotEmpty ? _branches.first['id']?.toString() : '1';
        _loadingBranches = false;
      });
    } catch (_) {
      final cached = await OfflineCache.loadList(OfflineCache.branches);
      if (!mounted) return;
      setState(() {
        _branches = cached.rows;
        _branchId ??= _branches.isNotEmpty ? _branches.first['id']?.toString() : '1';
        _loadingBranches = false;
      });
    }
  }

  Future<void> _loadPayables() async {
    setState(() => _loadingPayables = true);
    try {
      await widget.api.ensureConfigured();
      final q = _payableSearchController.text.trim();
      final data = await widget.api.getList(
        '/disbursements/payables',
        query: q.isNotEmpty ? {'q': q} : null,
      );
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.disbursementPayables, rows);
      if (!mounted) return;
      setState(() {
        _payables = rows;
        _loadingPayables = false;
        if (_selectedPayable != null) {
          final id = _selectedPayable!['transNo'] ?? _selectedPayable!['id'];
          final updated = rows.cast<Map<String, dynamic>?>().firstWhere(
                (r) => r?['transNo'] == id || r?['id'] == id,
                orElse: () => null,
              );
          if (updated == null) {
            _clearSelection();
          } else {
            _selectedPayable = updated;
            _totalController.text = ((updated['balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
            _syncTotals();
          }
        }
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.disbursementPayables);
      if (!mounted) return;
      setState(() {
        _payables = cached.rows;
        _fromCache = cached.rows.isNotEmpty;
        _offlineLabel = cached.rows.isNotEmpty ? OfflineCache.staleLabel(cached.savedAt) : null;
        _error = friendlyApiError(error);
        _loadingPayables = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      await widget.api.ensureConfigured();
      final query = <String, String>{};
      if (_historyFrom != null) query['from'] = _formatApiDate(_historyFrom!);
      if (_historyTo != null) query['to'] = _formatApiDate(_historyTo!);
      final q = _historySearchController.text.trim();
      if (q.isNotEmpty) query['q'] = q;

      final data = await widget.api.getList('/disbursements', query: query.isEmpty ? null : query);
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.disbursements, rows);
      if (!mounted) return;
      setState(() {
        _history = rows;
        _loadingHistory = false;
        _fromCache = false;
        _offlineLabel = null;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.disbursements);
      if (!mounted) return;
      setState(() {
        _history = cached.rows;
        _fromCache = cached.rows.isNotEmpty;
        _offlineLabel = cached.rows.isNotEmpty ? OfflineCache.staleLabel(cached.savedAt) : null;
        _error = friendlyApiError(error);
        _loadingHistory = false;
      });
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPick,
    bool allowWhenOffline = false,
  }) async {
    if (_fromCache && !allowWhenOffline) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _save() async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final payable = _selectedPayable;
    if (payable == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a payable to disburse.')));
      return;
    }

    final due = _parse(_dueController);
    final paid = _parse(_amountPaidController);
    if (due <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount due must be greater than zero.')));
      return;
    }
    if (paid < due) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount paid must cover the amount due.')));
      return;
    }
    if (_paymentMethod == 'CHECK' && _checkNoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter check number.')));
      return;
    }

    final apEntryId = payable['dbId'] ?? payable['apEntryId'] ?? payable['id'];
    setState(() => _saving = true);
    try {
      await widget.api.post('/disbursements', {
        'apEntryId': apEntryId,
        if (_branchId != null) 'branchId': _branchId,
        'transactionDate': _formatApiDate(_transactionDate),
        'referenceNo': _referenceNoController.text.trim(),
        'referenceDate': _formatApiDate(_referenceDate),
        'paymentMethod': _paymentMethod,
        if (_checkNoController.text.trim().isNotEmpty) 'checkNo': _checkNoController.text.trim(),
        'totalAmount': _parse(_totalController),
        'discount': _parse(_discountController),
        'dueAmount': due,
        'amountPaid': paid,
        'changeAmount': _parse(_changeController),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disbursement saved.')));
      _clearSelection();
      await Future.wait([_loadPayables(), _loadHistory()]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _moneyField(String label, TextEditingController c, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        readOnly: readOnly || _fromCache,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: readOnly ? null : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        decoration: _disbField(label),
      ),
    );
  }

  void _showHistoryDetail(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row['transNo']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text('AP: ${row['apTransNo'] ?? '—'}'),
            Text('Supplier: ${row['supplierName'] ?? '—'}'),
            Text('Project: ${row['projectName'] ?? '—'}'),
            Text('Branch: ${row['branchName'] ?? '—'}'),
            Text('Reference: ${row['referenceNo'] ?? '—'}'),
            Text('Method: ${row['paymentMethod'] ?? '—'}'),
            const SizedBox(height: 8),
            Text('Applied: ${fieldFormatMoney(row['amountApplied'] ?? row['dueAmount'])}'),
            Text('Paid: ${fieldFormatMoney(row['amountPaid'])} · Change: ${fieldFormatMoney(row['changeAmount'])}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);
    final selected = _selectedPayable;

    return RefreshIndicator(
      onRefresh: _bootstrap,
      color: AppTheme.maroon,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_fromCache && _offlineLabel != null)
            FieldOfflineBanner(label: _offlineLabel!, hint: offlineListBannerHint(_error)),
          if (_error != null && _payables.isEmpty && _history.isEmpty)
            FieldErrorBanner(message: _error!, onRetry: _bootstrap),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Payables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _payableSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search payables',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadPayables(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _loadingPayables ? null : _loadPayables,
                      child: Text(_loadingPayables ? 'Loading…' : 'Search'),
                    ),
                  ),
                  const Divider(height: 20),
                  if (_loadingPayables && _payables.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_payables.isEmpty)
                    const FieldEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No open payables',
                      subtitle: 'Create AP entries or clear existing balances.',
                    )
                  else
                    ..._payables.map((row) {
                      final isSelected = selected != null &&
                          (selected['transNo'] == row['transNo'] || selected['id'] == row['id']);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? AppTheme.maroon.withValues(alpha: 0.06) : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['transNo']?.toString() ?? '—',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    row['displayDate']?.toString() ?? row['transDate']?.toString() ?? '—',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              Text(row['supplierName']?.toString() ?? '—', style: const TextStyle(fontSize: 12)),
                              Text(row['projectName']?.toString() ?? '—', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Balance ${fieldFormatMoney(row['balance'] ?? row['amount'])}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                                  ),
                                  const Spacer(),
                                  FilledButton.tonal(
                                    onPressed: _fromCache ? null : () => _selectPayable(row),
                                    child: const Text('Disburse'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Disbursement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (selected == null)
                    const Text(
                      'Select a payable above, then enter payment details.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  else ...[
                    _readOnlyLine('Supplier', selected['supplierName']?.toString()),
                    _readOnlyLine('Project', selected['projectName']?.toString()),
                    _readOnlyLine('Invoice No', selected['invoiceNo']?.toString()),
                    _readOnlyLine('AP Trans No', selected['transNo']?.toString()),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _referenceNoController,
                      readOnly: _fromCache,
                      decoration: _disbField('Reference No'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _fromCache
                          ? null
                          : () => _pickDate(
                                initial: _referenceDate,
                                onPick: (d) => setState(() => _referenceDate = d),
                              ),
                      child: InputDecorator(
                        decoration: _disbField('Reference Date'),
                        child: Text(_formatApiDate(_referenceDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _fromCache
                          ? null
                          : () => _pickDate(
                                initial: _transactionDate,
                                onPick: (d) => setState(() => _transactionDate = d),
                              ),
                      child: InputDecorator(
                        decoration: _disbField('Transaction Date'),
                        child: Text(_formatApiDate(_transactionDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!_loadingBranches)
                      DropdownButtonFormField<String>(
                        key: ValueKey('br_$_branchId'),
                        isExpanded: true,
                        initialValue: _branchId,
                        decoration: _disbField('Branch'),
                        items: _branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['id']?.toString(),
                                child: Text(b['name']?.toString() ?? 'Branch', overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: _fromCache ? null : (v) => setState(() => _branchId = v),
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('pm_$_paymentMethod'),
                      isExpanded: true,
                      initialValue: _paymentMethod,
                      decoration: _disbField('Payment Method'),
                      items: _paymentMethods
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: _fromCache
                          ? null
                          : (v) => setState(() {
                                if (v != null) _paymentMethod = v;
                              }),
                    ),
                    if (_paymentMethod == 'CHECK') ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _checkNoController,
                        readOnly: _fromCache,
                        decoration: _disbField('Check No'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _moneyField('Total', _totalController, readOnly: true),
                    _moneyField('Discount', _discountController),
                    _moneyField('Due', _dueController, readOnly: true),
                    _moneyField('Amount Paid', _amountPaidController),
                    _moneyField('Change', _changeController, readOnly: true),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(onPressed: _clearSelection, child: const Text('Clear')),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving || _fromCache ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Disbursement history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            initial: _historyFrom ?? DateTime.now(),
                            onPick: (d) => setState(() => _historyFrom = d),
                            allowWhenOffline: true,
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date From',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _historyFrom == null ? '—' : _formatApiDate(_historyFrom!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            initial: _historyTo ?? DateTime.now(),
                            onPick: (d) => setState(() => _historyTo = d),
                            allowWhenOffline: true,
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date To',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _historyTo == null ? '—' : _formatApiDate(_historyTo!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _historySearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadHistory(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _loadingHistory ? null : _loadHistory,
                      child: Text(_loadingHistory ? 'Searching…' : 'Search'),
                    ),
                  ),
                  const Divider(height: 24),
                  if (_loadingHistory && _history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_history.isEmpty)
                    const FieldEmptyState(
                      icon: Icons.payments_outlined,
                      title: 'No disbursements yet',
                      subtitle: 'Payments you post will appear here.',
                    )
                  else ...[
                    const Row(
                      children: [
                        Expanded(child: Text('Trans No', style: headerStyle)),
                        Expanded(child: Text('Date', style: headerStyle)),
                        Expanded(flex: 2, child: Text('Supplier', style: headerStyle)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._history.map((row) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(row['transNo']?.toString() ?? '—'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['displayDate'] ?? row['transDate'] ?? '—'} · ${row['supplierName'] ?? '—'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(row['projectName']?.toString() ?? '—', style: const TextStyle(fontSize: 12)),
                              if ((row['branchName']?.toString() ?? '').isNotEmpty)
                                Text(row['branchName'].toString(), style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                fieldFormatMoney(row['amountApplied'] ?? row['dueAmount'] ?? row['amountPaid']),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.circle, color: Colors.orange, size: 22),
                            onPressed: () => _showHistoryDetail(row),
                          ),
                        ),
                      );
                    }),
                    Text(
                      'Showing ${_history.length} entr${_history.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyLine(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value?.trim().isNotEmpty == true ? value! : '—', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}