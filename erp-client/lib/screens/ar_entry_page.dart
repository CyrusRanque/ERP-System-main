// C:\ERP-System-main\erp-client\lib\screens\ar_entry_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

class _ArLineItem {
  const _ArLineItem({
    required this.accountLabel,
    required this.accountNumber,
    required this.monthlyFee,
  });

  final String accountLabel;
  final String accountNumber;
  final double monthlyFee;
}

InputDecoration _arFieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

/// Office **Create AR Entry** — contract + recurring item lines (`/ar-contracts`).
class ArEntryPage extends StatefulWidget {
  const ArEntryPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ArEntryPage> createState() => _ArEntryPageState();
}

class _ArEntryPageState extends State<ArEntryPage> {
  bool _loading = true;
  bool _fromCache = false;
  bool _saving = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _projects = [];

  String? _customerId;
  String? _projectId;
  DateTime _transactionDate = DateTime.now();
  DateTime? _contractStart;
  DateTime? _contractEnd;

  final _invoiceController = TextEditingController();
  final _withholdingController = TextEditingController(text: '0.00');
  final _retentionController = TextEditingController(text: '0.00');
  final _recoupmentController = TextEditingController(text: '0.00');
  final _mobilizationController = TextEditingController(text: '0.00');
  final _netController = TextEditingController(text: '0.00');
  final _remarksController = TextEditingController();
  final _contractAmountController = TextEditingController(text: '0.00');
  final _contractMonthlyController = TextEditingController(text: '0.00');
  final _headerNameController = TextEditingController();
  final _accountLocationController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _lineMonthlyFeeController = TextEditingController(text: '0.00');
  final _recurringDayController = TextEditingController();

  final List<_ArLineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _recurringDayController.text = '${DateTime.now().day}';
    _contractStart = DateTime.now();
    _contractEnd = DateTime.now();
    for (final c in [
      _withholdingController,
      _retentionController,
      _recoupmentController,
      _mobilizationController,
      _contractAmountController,
    ]) {
      c.addListener(_syncNetAmount);
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _withholdingController.dispose();
    _retentionController.dispose();
    _recoupmentController.dispose();
    _mobilizationController.dispose();
    _netController.dispose();
    _remarksController.dispose();
    _contractAmountController.dispose();
    _contractMonthlyController.dispose();
    _headerNameController.dispose();
    _accountLocationController.dispose();
    _accountNumberController.dispose();
    _lineMonthlyFeeController.dispose();
    _recurringDayController.dispose();
    super.dispose();
  }

  double _parseMoney(TextEditingController controller) {
    final raw = controller.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _syncNetAmount() {
    final base = _parseMoney(_contractAmountController);
    final deductions = _parseMoney(_withholdingController) +
        _parseMoney(_retentionController) +
        _parseMoney(_recoupmentController) +
        _parseMoney(_mobilizationController);
    final net = fieldRoundMoney((base - deductions).clamp(0, double.infinity));
    final text = net.toStringAsFixed(2);
    if (_netController.text != text) {
      _netController.text = text;
    }
  }

  double get _itemsMonthlyTotal => _lineItems.fold(0.0, (sum, i) => sum + i.monthlyFee);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.ensureConfigured();
      final results = await Future.wait([
        widget.api.getList('/setup/customers'),
        widget.api.getList('/setup/projects'),
      ]);
      final customers = results[0].cast<Map<String, dynamic>>();
      final projects = results[1].cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _customers = customers.where((c) => c['status'] != 'Inactive').toList();
        _projects = projects;
        _customerId ??= _customers.isNotEmpty ? _customers.first['id']?.toString() : null;
        _loading = false;
        _fromCache = false;
      });
      unawaited(
        Future.wait([
          OfflineCache.saveList(OfflineCache.soaCustomers, customers),
          OfflineCache.saveList(OfflineCache.projects, projects),
        ]),
      );
      _syncNetAmount();
    } catch (error) {
      final cachedCustomers = await OfflineCache.loadList(OfflineCache.soaCustomers);
      final cachedProjects = await OfflineCache.loadList(OfflineCache.projects);
      if (!mounted) return;
      if (cachedCustomers.rows.isNotEmpty) {
        setState(() {
          _customers = cachedCustomers.rows.where((c) => c['status'] != 'Inactive').toList();
          _projects = cachedProjects.rows;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cachedCustomers.savedAt);
          _loading = false;
        });
      } else {
        setState(() {
          _error = friendlyApiError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate({DateTime? initial, required ValueChanged<DateTime> onPicked}) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    onPicked(picked);
  }

  void _addLineItem() {
    final label = _accountLocationController.text.trim();
    final number = _accountNumberController.text.trim();
    final fee = _parseMoney(_lineMonthlyFeeController);
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter account name — location.')),
      );
      return;
    }
    if (fee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter monthly recurring fee greater than zero.')),
      );
      return;
    }
    setState(() {
      _lineItems.add(_ArLineItem(accountLabel: label, accountNumber: number, monthlyFee: fee));
      _accountLocationController.clear();
      _accountNumberController.clear();
      _lineMonthlyFeeController.text = '0.00';
    });
  }

  Future<void> _save() async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a client.')),
      );
      return;
    }

    final billingDay = int.tryParse(_recurringDayController.text.trim()) ?? 1;
    if (billingDay < 1 || billingDay > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run script day must be between 1 and 31.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = {
        'customerId': customerId,
        if (_projectId != null && _projectId!.isNotEmpty) 'projectId': _projectId,
        'contractAmount': _parseMoney(_contractAmountController),
        'monthlyFee': _parseMoney(_contractMonthlyController),
        if (_contractStart != null) 'startDate': _formatApiDate(_contractStart!),
        if (_contractEnd != null) 'endDate': _formatApiDate(_contractEnd!),
        'billingDay': billingDay,
        'transactionDate': _formatApiDate(_transactionDate),
        if (_invoiceController.text.trim().isNotEmpty) 'invoiceNo': _invoiceController.text.trim(),
        'withholding': _parseMoney(_withholdingController),
        'retention': _parseMoney(_retentionController),
        'recoupment': _parseMoney(_recoupmentController),
        'mobilization': _parseMoney(_mobilizationController),
        'netAmount': _parseMoney(_netController),
        if (_remarksController.text.trim().isNotEmpty) 'remarks': _remarksController.text.trim(),
        if (_headerNameController.text.trim().isNotEmpty) 'headerName': _headerNameController.text.trim(),
        'lines': _lineItems
            .map(
              (item) => {
                'accountLabel': item.accountLabel,
                'accountNumber': item.accountNumber,
                'monthlyFee': item.monthlyFee,
              },
            )
            .toList(),
      };

      await widget.api.post('/ar-contracts', body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AR entry saved.')),
      );
      setState(() {
        _lineItems.clear();
        _invoiceController.clear();
        _remarksController.clear();
        _headerNameController.clear();
        _withholdingController.text = '0.00';
        _retentionController.text = '0.00';
        _recoupmentController.text = '0.00';
        _mobilizationController.text = '0.00';
        _contractAmountController.text = '0.00';
        _contractMonthlyController.text = '0.00';
      });
      _syncNetAmount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _moneyField(String label, TextEditingController controller, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly || _fromCache,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: readOnly
            ? null
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        decoration: _arFieldDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _customers.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.maroon,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_fromCache && _offlineLabel != null)
            FieldOfflineBanner(label: _offlineLabel!, hint: offlineListBannerHint(_error)),
          if (_error != null && !_fromCache) FieldErrorBanner(message: _error!, onRetry: _load),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create AR Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('ar_client_$_customerId'),
                    isExpanded: true,
                    initialValue: _customerId?.isNotEmpty == true ? _customerId : null,
                    decoration: _arFieldDecoration('Client'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Select —')),
                      ..._customers.map(
                        (c) => DropdownMenuItem(
                          value: c['id']?.toString(),
                          child: Text(c['name']?.toString() ?? 'Customer', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _fromCache ? null : (v) => setState(() => _customerId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('ar_project_$_projectId'),
                    isExpanded: true,
                    initialValue: _projectId?.isNotEmpty == true ? _projectId : null,
                    decoration: _arFieldDecoration('Project'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Select —')),
                      ..._projects.map(
                        (p) => DropdownMenuItem(
                          value: p['id']?.toString(),
                          child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _fromCache ? null : (v) => setState(() => _projectId = v),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _fromCache
                        ? null
                        : () => _pickDate(
                              initial: _transactionDate,
                              onPicked: (d) => setState(() => _transactionDate = d),
                            ),
                    child: InputDecorator(
                      decoration: _arFieldDecoration('Transaction date'),
                      child: Text(_formatApiDate(_transactionDate)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _invoiceController,
                    readOnly: _fromCache,
                    decoration: _arFieldDecoration('Invoice No'),
                  ),
                  _moneyField('Withholding Tax Amount', _withholdingController),
                  _moneyField('Retention Amount', _retentionController),
                  _moneyField('Recoupment Amount', _recoupmentController),
                  _moneyField('Mobilization Amount', _mobilizationController),
                  _moneyField('Net Amount', _netController, readOnly: true),
                  TextFormField(
                    controller: _remarksController,
                    readOnly: _fromCache,
                    maxLines: 3,
                    decoration: _arFieldDecoration('Remarks'),
                  ),
                  const SizedBox(height: 6),
                  _moneyField('Contract Amount', _contractAmountController),
                  _moneyField('Monthly Recurring', _contractMonthlyController),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _fromCache
                              ? null
                              : () => _pickDate(
                                    initial: _contractStart,
                                    onPicked: (d) => setState(() {
                                      _contractStart = d;
                                      if (_contractEnd != null && _contractEnd!.isBefore(d)) {
                                        _contractEnd = d;
                                      }
                                    }),
                                  ),
                          child: InputDecorator(
                            decoration: _arFieldDecoration('Start date'),
                            child: Text(_contractStart == null ? '—' : _formatApiDate(_contractStart!)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _fromCache
                              ? null
                              : () => _pickDate(
                                    initial: _contractEnd,
                                    onPicked: (d) => setState(() {
                                      _contractEnd = d;
                                      if (_contractStart != null && _contractStart!.isAfter(d)) {
                                        _contractStart = d;
                                      }
                                    }),
                                  ),
                          child: InputDecorator(
                            decoration: _arFieldDecoration('End date'),
                            child: Text(_contractEnd == null ? '—' : _formatApiDate(_contractEnd!)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Every', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 56,
                        child: TextFormField(
                          controller: _recurringDayController,
                          readOnly: _fromCache,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _arFieldDecoration('Day'),
                        ),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 14, left: 8),
                          child: Text('of the month', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8D48A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _headerNameController,
                          readOnly: _fromCache,
                          decoration: _arFieldDecoration('Header name'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _accountLocationController,
                          readOnly: _fromCache,
                          decoration: _arFieldDecoration('Add account name — location'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _accountNumberController,
                          readOnly: _fromCache,
                          decoration: _arFieldDecoration('Add account number'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _lineMonthlyFeeController,
                          readOnly: _fromCache,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          decoration: _arFieldDecoration('Monthly recurring fee'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _fromCache ? null : _addLineItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add line'),
                        ),
                      ],
                    ),
                  ),
                  if (_lineItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(flex: 3, child: Text('ACCOUNT NAME — LOCATION', style: headerStyle)),
                        Expanded(flex: 2, child: Text('ACCOUNT NO.', style: headerStyle)),
                        Expanded(
                          flex: 2,
                          child: Text('MONTHLY FEE', style: headerStyle, textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    ..._lineItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(item.accountLabel, style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(item.accountNumber.isEmpty ? '—' : item.accountNumber, style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                fieldFormatMoney(item.monthlyFee),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (!_fromCache)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => setState(() => _lineItems.removeAt(i)),
                              ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          flex: 5,
                          child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            fieldFormatMoney(_itemsMonthlyTotal),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                          ),
                        ),
                        if (!_fromCache) const SizedBox(width: 48),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _saving || _fromCache ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}