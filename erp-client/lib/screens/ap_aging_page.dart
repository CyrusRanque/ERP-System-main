import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/document_print.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';
import '../widgets/print_document_button.dart';

const _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);

/// Office **AP Aging** — branch filter, View report, Print PDF.
class ApAgingPage extends StatefulWidget {
  const ApAgingPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ApAgingPage> createState() => _ApAgingPageState();
}

class _ApAgingPageState extends State<ApAgingPage> {
  bool _loadingSetup = true;
  bool _loadingReport = false;
  bool _showReport = false;
  bool _fromCache = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _branches = [];
  String? _branchId;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
    });
    try {
      await widget.api.ensureConfigured();
      final data = await widget.api.getList('/setup/branches');
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.branches, rows);
      if (!mounted) return;
      setState(() {
        _branches = rows.where((b) => b['status'] != 'Inactive').toList();
        _branchId ??= _branches.isNotEmpty ? _branches.first['id']?.toString() : '1';
        _loadingSetup = false;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.branches);
      if (!mounted) return;
      setState(() {
        _branches = cached.rows;
        _branchId ??= _branches.isNotEmpty ? _branches.first['id']?.toString() : '1';
        _loadingSetup = false;
        if (_branches.isEmpty) _error = friendlyApiError(error);
      });
    }
  }

  Future<void> _viewReport() async {
    final branchId = _branchId ?? '1';
    setState(() {
      _loadingReport = true;
      _error = null;
      _fromCache = false;
      _offlineLabel = null;
    });
    try {
      await widget.api.ensureConfigured();
      final report = await widget.api.getData('/reports/ap-aging', query: {'branchId': branchId});
      await OfflineCache.saveApAgingReport(branchId, report);
      if (!mounted) return;
      setState(() {
        _report = report;
        _showReport = true;
        _loadingReport = false;
      });
    } catch (error) {
      final cached = await OfflineCache.loadApAgingReport(branchId);
      if (!mounted) return;
      if (cached.data != null) {
        setState(() {
          _report = cached.data;
          _showReport = true;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
          _loadingReport = false;
        });
      } else {
        setState(() {
          _error = friendlyApiError(error);
          _loadingReport = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _suppliers() {
    if (_report == null) return [];
    return (_report!['suppliers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _agingTable() {
    final suppliers = _suppliers();
    final grand = (_report?['grandTotal'] as Map?)?.cast<String, dynamic>() ?? {};

    if (_loadingReport) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_showReport) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Select branch and tap VIEW to generate AP Aging.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    if (suppliers.isEmpty) {
      return const FieldEmptyState(
        icon: Icons.hourglass_empty_outlined,
        title: 'No open payables',
        subtitle: 'Nothing to age for this branch.',
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
          columnSpacing: 14,
          horizontalMargin: 10,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          columns: const [
            DataColumn(label: Text('Supplier', style: _headerStyle)),
            DataColumn(label: Text('Current', style: _headerStyle), numeric: true),
            DataColumn(label: Text('31–60', style: _headerStyle), numeric: true),
            DataColumn(label: Text('61–90', style: _headerStyle), numeric: true),
            DataColumn(label: Text('Over 90', style: _headerStyle), numeric: true),
            DataColumn(label: Text('Total', style: _headerStyle), numeric: true),
          ],
          rows: [
            ...suppliers.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row['supplierName']?.toString() ?? '—')),
                  DataCell(Text(_cellMoney(row['current']))),
                  DataCell(Text(_cellMoney(row['days31_60']))),
                  DataCell(Text(_cellMoney(row['days61_90']))),
                  DataCell(Text(_cellMoney(row['over90']))),
                  DataCell(
                    Text(
                      fieldFormatMoney(row['total']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            }),
            DataRow(
              color: WidgetStateProperty.all(const Color(0xFFFAFAFA)),
              cells: [
                const DataCell(Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text(_cellMoney(grand['current']), style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(_cellMoney(grand['days31_60']), style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(_cellMoney(grand['days61_90']), style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(_cellMoney(grand['over90']), style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(
                  Text(
                    fieldFormatMoney(grand['total']),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.maroon),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cellMoney(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return amount > 0 ? fieldFormatMoney(amount) : '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSetup) {
      return const Center(child: CircularProgressIndicator());
    }

    final branchName =
        _branches.cast<Map<String, dynamic>?>().firstWhere(
              (b) => b?['id']?.toString() == _branchId,
              orElse: () => null,
            )?['name'] ??
            _report?['branchName']?.toString();

    return RefreshIndicator(
      onRefresh: _loadBranches,
      color: AppTheme.maroon,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_fromCache && _offlineLabel != null)
            FieldOfflineBanner(label: _offlineLabel!, hint: offlineListBannerHint(_error)),
          if (_error != null) FieldErrorBanner(message: _error!, onRetry: _viewReport),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'AP Aging',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('br_$_branchId'),
                  isExpanded: true,
                  isDense: true,
                  initialValue: _branchId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id']?.toString(),
                          child: Text(b['name']?.toString() ?? 'Branch', overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingReport
                      ? null
                      : (value) {
                          setState(() {
                            _branchId = value;
                            _showReport = false;
                            _report = null;
                          });
                        },
                ),
              ),
              const SizedBox(width: 8),
              PrintDocumentButton(
                label: 'Print',
                enabled: _showReport && _report != null,
                onPrint: () => DocumentPrint.shareApAging(_report!),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadingReport ? null : _viewReport,
                child: Text(_loadingReport ? '…' : 'View'),
              ),
            ],
          ),
          if (_showReport && _report != null) ...[
            const SizedBox(height: 8),
            Text(
              'As of ${_report!['asOf'] ?? '—'}${branchName != null ? ' · $branchName' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _agingTable(),
            ),
          ),
        ],
      ),
    );
  }
}