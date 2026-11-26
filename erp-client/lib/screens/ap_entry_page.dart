import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';
import '../widgets/mobile_setup_sheets.dart';

InputDecoration _apField(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

/// Office **Create AP Entry** — supplier, project, entry form + searchable list.
class ApEntryPage extends StatefulWidget {
  const ApEntryPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ApEntryPage> createState() => _ApEntryPageState();
}

class _ApEntryPageState extends State<ApEntryPage> {
  bool _loadingList = true;
  bool _loadingSetup = true;
  bool _fromCache = false;
  bool _saving = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _suppliers = [];

  String? _supplierId;
  String? _projectId;
  DateTime _transactionDate = DateTime.now();
  DateTime? _filterFrom;
  DateTime? _filterTo;

  final _invoiceController = TextEditingController();
  final _amountController = TextEditingController();
  final _particularsController = TextEditingController();
  final _remarksController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterFrom = DateTime(now.year, now.month, 1);
    _filterTo = now;
    _bootstrap();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _amountController.dispose();
    _particularsController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadSetup(), _loadList()]);
  }

  Future<void> _addSupplier() async {
    final created = await showAddSupplierSheet(context, widget.api);
    if (created == null || !mounted) return;
    setState(() {
      _suppliers.add(created);
      _supplierId = created['id']?.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supplier saved to the database.')),
    );
  }

  Future<void> _loadSetup() async {
    setState(() => _loadingSetup = true);
    try {
      await widget.api.ensureConfigured();
      final results = await Future.wait([
        widget.api.getList('/setup/projects'),
        widget.api.getList('/setup/suppliers'),
      ]);
      final projects = results[0].cast<Map<String, dynamic>>();
      final suppliers = results[1].cast<Map<String, dynamic>>();
      await Future.wait([
        OfflineCache.saveList(OfflineCache.projects, projects),
        OfflineCache.saveList(OfflineCache.suppliers, suppliers),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = projects.where(fieldSetupRowIsActive).toList();
        _suppliers = suppliers.where(fieldSetupRowIsActive).toList();
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _supplierId ??= _suppliers.isNotEmpty ? _suppliers.first['id']?.toString() : null;
        _loadingSetup = false;
      });
    } catch (error) {
      final cachedProjects = await OfflineCache.loadList(OfflineCache.projects);
      final cachedSuppliers = await OfflineCache.loadList(OfflineCache.suppliers);
      if (!mounted) return;
      setState(() {
        _projects = cachedProjects.rows;
        _suppliers = cachedSuppliers.rows.where(fieldSetupRowIsActive).toList();
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _supplierId ??= _suppliers.isNotEmpty ? _suppliers.first['id']?.toString() : null;
        _loadingSetup = false;
        _fromCache = cachedProjects.rows.isNotEmpty || cachedSuppliers.rows.isNotEmpty;
      });
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _loadingList = true;
      if (!_fromCache) _error = null;
    });
    try {
      await widget.api.ensureConfigured();
      final query = <String, String>{};
      if (_filterFrom != null) query['from'] = _formatApiDate(_filterFrom!);
      if (_filterTo != null) query['to'] = _formatApiDate(_filterTo!);
      final q = _searchController.text.trim();
      if (q.isNotEmpty) query['q'] = q;

      final data = await widget.api.getList('/ap-entries', query: query);
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.apEntries, rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingList = false;
        _fromCache = false;
        _offlineLabel = null;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.apEntries);
      if (!mounted) return;
      if (cached.rows.isNotEmpty) {
        setState(() {
          _rows = cached.rows;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
          _error = friendlyApiError(error);
          _loadingList = false;
        });
      } else {
        setState(() {
          _error = friendlyApiError(error);
          _loadingList = false;
        });
      }
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
    final supplierId = _supplierId;
    final projectId = _projectId;
    if (supplierId == null || supplierId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a supplier.')));
      return;
    }
    if (projectId == null || projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a project.')));
      return;
    }
    final amount = _parseAmount();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.post('/ap-entries', {
        'supplierId': supplierId,
        'projectId': projectId,
        'transactionDate': _formatApiDate(_transactionDate),
        'amount': amount,
        if (_invoiceController.text.trim().isNotEmpty) 'invoiceNo': _invoiceController.text.trim(),
        if (_particularsController.text.trim().isNotEmpty) 'particulars': _particularsController.text.trim(),
        if (_remarksController.text.trim().isNotEmpty) 'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AP entry saved.')));
      _invoiceController.clear();
      _amountController.clear();
      _particularsController.clear();
      _remarksController.clear();
      await _loadList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final id = row['transNo']?.toString() ?? fieldRowId(row);
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete AP entry?'),
        content: Text('Remove $id?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.request('DELETE', '/ap-entries/${Uri.encodeComponent(id)}');
      await _loadList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(error))));
    }
  }

  void _showRowDetail(Map<String, dynamic> row) {
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
            Text('Supplier: ${row['supplierName'] ?? '—'}'),
            Text('Project: ${row['projectName'] ?? '—'}'),
            Text('Invoice: ${row['invoiceNo'] ?? '—'}'),
            Text('Amount: ${fieldFormatMoney(row['amount'])}'),
            Text('Status: ${row['status'] ?? '—'}'),
            const SizedBox(height: 8),
            Text(row['particulars']?.toString() ?? '—'),
            if ((row['remarks']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Remarks: ${row['remarks']}', style: const TextStyle(color: AppTheme.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String? status) {
    final label = (status ?? 'UNPAID').toString().toUpperCase();
    final isPaid = label == 'PAID' || label == 'CLOSED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isPaid ? Colors.green : Colors.red.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPaid ? Colors.green.shade800 : Colors.red.shade800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSetup && _projects.isEmpty && _suppliers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _bootstrap,
      color: AppTheme.maroon,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_fromCache && _offlineLabel != null)
            FieldOfflineBanner(label: _offlineLabel!, hint: offlineListBannerHint(_error)),
          if (_error != null && _rows.isEmpty)
            FieldErrorBanner(message: _error!, onRetry: _loadList),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create AP Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  if (_suppliers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'No active suppliers in setup.',
                        style: TextStyle(color: AppTheme.resolve(context).textSecondary, fontSize: 13),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _fromCache ? null : _addSupplier,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add supplier'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('sup_$_supplierId'),
                    isExpanded: true,
                    initialValue: _supplierId,
                    decoration: _apField('Supplier'),
                    items: _suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id']?.toString(),
                            child: Text(s['name']?.toString() ?? 'Supplier', overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _fromCache ? null : (v) => setState(() => _supplierId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('prj_$_projectId'),
                    isExpanded: true,
                    initialValue: _projectId,
                    decoration: _apField('Project'),
                    items: _projects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p['id']?.toString(),
                            child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _fromCache ? null : (v) => setState(() => _projectId = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _invoiceController,
                    readOnly: _fromCache,
                    decoration: _apField('Invoice No'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    readOnly: _fromCache,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: _apField('Amount'),
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
                      decoration: _apField('Transaction date'),
                      child: Text(_formatApiDate(_transactionDate)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _particularsController,
                    readOnly: _fromCache,
                    maxLines: 4,
                    decoration: _apField('Particulars'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _remarksController,
                    readOnly: _fromCache,
                    maxLines: 2,
                    decoration: _apField('Remarks'),
                  ),
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
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            initial: _filterFrom ?? DateTime.now(),
                            onPick: (d) => setState(() => _filterFrom = d),
                            allowWhenOffline: true,
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date From',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _filterFrom == null ? '—' : _formatApiDate(_filterFrom!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(
                            initial: _filterTo ?? DateTime.now(),
                            onPick: (d) => setState(() => _filterTo = d),
                            allowWhenOffline: true,
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date To',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _filterTo == null ? '—' : _formatApiDate(_filterTo!),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadList(),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _loadingList ? null : _loadList,
                      child: Text(_loadingList ? 'Searching…' : 'Search'),
                    ),
                  ),
                  const Divider(height: 24),
                  if (_loadingList && _rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_rows.isEmpty)
                    const FieldEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No AP entries',
                      subtitle: 'Adjust the date range or add a new entry.',
                    )
                  else
                    ..._rows.map((row) {
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
                              if ((row['invoiceNo']?.toString() ?? '').isNotEmpty)
                                Text('Inv: ${row['invoiceNo']}', style: const TextStyle(fontSize: 12)),
                              if ((row['particulars']?.toString() ?? '').isNotEmpty)
                                Text(
                                  row['particulars'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    fieldFormatMoney(row['amount']),
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                                  ),
                                  const SizedBox(width: 8),
                                  _statusChip(row['status']?.toString()),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.circle, color: Colors.orange, size: 22),
                            onPressed: () => _showRowDetail(row),
                            onLongPress: _fromCache ? null : () => _deleteRow(row),
                          ),
                        ),
                      );
                    }),
                  if (_rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Showing ${_rows.length} entr${_rows.length == 1 ? 'y' : 'ies'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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