import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

InputDecoration _pcField(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

/// Office **Create Petty Cash** — entry form + dated list with delete.
class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  bool _loadingList = true;
  bool _loadingSetup = true;
  bool _fromCache = false;
  bool _saving = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _projects = [];

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

  Future<void> _bootstrap() async {
    await Future.wait([_loadProjects(), _loadList()]);
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingSetup = true);
    try {
      await widget.api.ensureConfigured();
      final data = await widget.api.getList('/setup/projects');
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.projects, rows);
      if (!mounted) return;
      setState(() {
        _projects = rows.where((p) => p['status'] != 'Inactive').toList();
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _loadingSetup = false;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.projects);
      if (!mounted) return;
      setState(() {
        _projects = cached.rows;
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _loadingSetup = false;
        _fromCache = cached.rows.isNotEmpty;
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

      final data = await widget.api.getList('/petty-cash', query: query);
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.pettyCash, rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingList = false;
        _fromCache = false;
        _offlineLabel = null;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.pettyCash);
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
  }) async {
    if (_fromCache) {
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
    final projectId = _projectId;
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
      await widget.api.post('/petty-cash', {
        'projectId': projectId,
        'transactionDate': _formatApiDate(_transactionDate),
        'amount': amount,
        if (_invoiceController.text.trim().isNotEmpty) 'invoiceNo': _invoiceController.text.trim(),
        if (_particularsController.text.trim().isNotEmpty) 'particulars': _particularsController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Petty cash saved.')));
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
    final id = fieldRowId(row);
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete petty cash?'),
        content: Text('Remove ${row['transNo'] ?? row['id']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.api.request('DELETE', '/petty-cash/${Uri.encodeComponent(id)}');
      await _loadList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSetup && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);

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
                  const Text('Create Petty Cash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_projectId),
                    isExpanded: true,
                    initialValue: _projectId,
                    decoration: _pcField('Project'),
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
                    decoration: _pcField('Invoice No'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountController,
                    readOnly: _fromCache,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: _pcField('Amount'),
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
                      decoration: _pcField('Transaction date'),
                      child: Text(_formatApiDate(_transactionDate)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _particularsController,
                    readOnly: _fromCache,
                    maxLines: 3,
                    decoration: _pcField('Particulars'),
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
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date from',
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
                          ),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date to',
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
                  TextFormField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (_) => _loadList(),
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
                      icon: Icons.savings_outlined,
                      title: 'No petty cash entries',
                      subtitle: 'Adjust dates or create a new entry above.',
                    )
                  else ...[
                    const Row(
                      children: [
                        Expanded(child: Text('Trans No', style: headerStyle)),
                        Expanded(child: Text('Date', style: headerStyle)),
                        Expanded(flex: 2, child: Text('Employee', style: headerStyle)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._rows.map((row) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['transNo']?.toString() ?? row['id']?.toString() ?? '—',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    row['displayDate']?.toString() ?? row['transDate']?.toString() ?? '—',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (!_fromCache)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline, color: Colors.deepOrange),
                                      onPressed: () => _deleteRow(row),
                                    ),
                                ],
                              ),
                              Text(
                                row['employeeName']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Text(
                                row['projectName']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fieldFormatMoney(row['amount']),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                              ),
                              if ((row['particulars']?.toString() ?? '').isNotEmpty)
                                Text(
                                  row['particulars'].toString(),
                                  style: const TextStyle(fontSize: 12, height: 1.3),
                                ),
                              if ((row['remarks']?.toString() ?? '').isNotEmpty)
                                Text(
                                  row['remarks'].toString(),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Showing ${_rows.length} entr${_rows.length == 1 ? 'y' : 'ies'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
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
}