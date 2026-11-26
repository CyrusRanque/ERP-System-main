import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

InputDecoration _liqField(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

/// Office **Liquidation** — employee, project, entry form + searchable list.
class LiquidationPage extends StatefulWidget {
  const LiquidationPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<LiquidationPage> createState() => _LiquidationPageState();
}

class _LiquidationPageState extends State<LiquidationPage> {
  bool _loadingList = true;
  bool _loadingSetup = true;
  bool _fromCache = false;
  bool _saving = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _employees = [];

  String? _employeeId;
  String? _projectId;
  DateTime _transactionDate = DateTime.now();
  DateTime? _filterFrom;
  DateTime? _filterTo;

  final _invoiceController = TextEditingController();
  final _amountController = TextEditingController();
  final _particularsController = TextEditingController();
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
    _searchController.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  double _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  String _employeeLabel(Map<String, dynamic> user) {
    return user['name']?.toString() ?? user['login']?.toString() ?? 'Employee';
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadSetup(), _loadList()]);
  }

  Future<void> _loadSetup() async {
    setState(() => _loadingSetup = true);
    try {
      await widget.api.ensureConfigured();
      final results = await Future.wait([
        widget.api.getList('/setup/projects'),
        widget.api.getList('/setup/users'),
      ]);
      final projects = results[0].cast<Map<String, dynamic>>();
      final users = results[1].cast<Map<String, dynamic>>();
      await Future.wait([
        OfflineCache.saveList(OfflineCache.projects, projects),
        OfflineCache.saveList(OfflineCache.setupUsers, users),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = projects.where((p) => p['status'] != 'Inactive').toList();
        _employees = users.where((u) => u['status'] != 'Inactive').toList();
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _employeeId ??= _employees.isNotEmpty ? _employees.first['id']?.toString() : null;
        _loadingSetup = false;
      });
    } catch (error) {
      final cachedProjects = await OfflineCache.loadList(OfflineCache.projects);
      final cachedUsers = await OfflineCache.loadList(OfflineCache.setupUsers);
      if (!mounted) return;
      setState(() {
        _projects = cachedProjects.rows;
        _employees = cachedUsers.rows.where((u) => u['status'] != 'Inactive').toList();
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _employeeId ??= _employees.isNotEmpty ? _employees.first['id']?.toString() : null;
        _loadingSetup = false;
        _fromCache = cachedProjects.rows.isNotEmpty;
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

      final data = await widget.api.getList('/liquidations', query: query);
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.liquidations, rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingList = false;
        _fromCache = false;
        _offlineLabel = null;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.liquidations);
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
    if (_employeeId == null || _employeeId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an employee.')));
      return;
    }
    if (_projectId == null || _projectId!.isEmpty) {
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
      await widget.api.post('/liquidations', {
        'employeeId': _employeeId,
        'projectId': _projectId,
        'transactionDate': _formatApiDate(_transactionDate),
        'amount': amount,
        if (_invoiceController.text.trim().isNotEmpty) 'invoiceNo': _invoiceController.text.trim(),
        if (_particularsController.text.trim().isNotEmpty) 'particulars': _particularsController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liquidation saved.')));
      _invoiceController.clear();
      _amountController.clear();
      _particularsController.clear();
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
        title: const Text('Delete liquidation?'),
        content: Text('Remove $id?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.request('DELETE', '/liquidations/${Uri.encodeComponent(id)}');
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
            Text('Employee: ${row['employeeName'] ?? '—'}'),
            Text('Project: ${row['projectName'] ?? '—'}'),
            Text('Amount: ${fieldFormatMoney(row['amount'])}'),
            const SizedBox(height: 8),
            Text(row['particulars']?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSetup && _projects.isEmpty && _employees.isEmpty) {
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Liquidation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('emp_$_employeeId'),
                    isExpanded: true,
                    initialValue: _employeeId,
                    decoration: _liqField('Employee'),
                    items: _employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e['id']?.toString(),
                            child: Text(_employeeLabel(e), overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _fromCache ? null : (v) => setState(() => _employeeId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('prj_$_projectId'),
                    isExpanded: true,
                    initialValue: _projectId,
                    decoration: _liqField('Project'),
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
                    decoration: _liqField('Invoice No'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    readOnly: _fromCache,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: _liqField('Amount'),
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
                      decoration: _liqField('Transaction Date'),
                      child: Text(_formatApiDate(_transactionDate)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _particularsController,
                    readOnly: _fromCache,
                    maxLines: 4,
                    decoration: _liqField('Particulars'),
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
                      icon: Icons.fact_check_outlined,
                      title: 'No liquidation entries',
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
                                '${row['displayDate'] ?? row['transDate'] ?? '—'} · ${row['employeeName'] ?? '—'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(row['projectName']?.toString() ?? '—', style: const TextStyle(fontSize: 12)),
                              if ((row['particulars']?.toString() ?? '').isNotEmpty)
                                Text(
                                  row['particulars'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                fieldFormatMoney(row['amount']),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
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