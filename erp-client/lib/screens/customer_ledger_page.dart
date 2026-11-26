import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';
import '../widgets/print_document_button.dart';

/// Customer ledger report (`GET /reports/customer-ledger`).
class CustomerLedgerPage extends StatefulWidget {
  const CustomerLedgerPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  bool _loadingCustomers = true;
  bool _loadingLedger = false;
  bool _fromCache = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _customers = [];
  String? _customerId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Map<String, dynamic>? _account;

  String? _formatApiDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'Any';
    return _formatApiDate(date)!;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) {
          _dateFrom = picked;
        }
      }
    });
  }

  Future<void> _loadCustomers() async {
    final wasOffline = _fromCache;
    setState(() {
      _loadingCustomers = true;
      _error = null;
      _fromCache = false;
      _offlineLabel = null;
    });
    try {
      await widget.api.ensureConfigured();
      final data = await widget.api.getList('/setup/customers');
      final rows = data.cast<Map<String, dynamic>>();
      await OfflineCache.saveList(OfflineCache.soaCustomers, rows);
      if (!mounted) return;
      setState(() {
        _customers = rows.where((c) => c['status'] != 'Inactive').toList();
        _customerId ??= _customers.isNotEmpty ? _customers.first['id']?.toString() : null;
        _loadingCustomers = false;
      });
      if (_customerId != null) {
        await _loadLedger();
      }
      if (wasOffline && mounted) fieldShowBackOnlineSnackBar(context);
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.soaCustomers);
      if (!mounted) return;
      if (cached.rows.isNotEmpty) {
        setState(() {
          _customers = cached.rows.where((c) => c['status'] != 'Inactive').toList();
          _customerId ??= _customers.isNotEmpty ? _customers.first['id']?.toString() : null;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
          _loadingCustomers = false;
        });
        if (_customerId != null) {
          await _loadLedger();
        }
      } else {
        setState(() {
          _error = friendlyApiError(error);
          _loadingCustomers = false;
        });
      }
    }
  }

  Future<void> _loadLedger() async {
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) return;

    final from = _formatApiDate(_dateFrom);
    final to = _formatApiDate(_dateTo);
    final wasOffline = _fromCache;

    setState(() {
      _loadingLedger = true;
      if (!wasOffline) _error = null;
    });

    if (_fromCache) {
      final cached = await OfflineCache.loadCustomerLedgerReport(customerId, from: from, to: to);
      if (!mounted) return;
      if (cached.data != null) {
        setState(() {
          _account = cached.data;
          _loadingLedger = false;
          _offlineLabel ??= OfflineCache.staleLabel(cached.savedAt);
        });
        return;
      }
    }

    try {
      final query = <String, String>{'customerId': customerId};
      if (from != null) query['from'] = from;
      if (to != null) query['to'] = to;

      final account = await widget.api.getData('/reports/customer-ledger', query: query);
      await OfflineCache.saveCustomerLedgerReport(customerId, from: from, to: to, account: account);
      if (!mounted) return;
      setState(() {
        _account = account;
        _loadingLedger = false;
      });
      if (wasOffline && mounted) fieldShowBackOnlineSnackBar(context);
    } catch (error) {
      final cached = await OfflineCache.loadCustomerLedgerReport(customerId, from: from, to: to);
      if (!mounted) return;
      if (cached.data != null) {
        setState(() {
          _account = cached.data;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
          _loadingLedger = false;
        });
      } else {
        setState(() {
          _error = friendlyApiError(error);
          _loadingLedger = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCustomers) {
      return const Center(child: CircularProgressIndicator());
    }

    final totals = (_account?['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final rows = (_account?['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final customer = _customers.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['id']?.toString() == _customerId,
          orElse: () => null,
        );

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      color: AppTheme.maroon,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_fromCache && _offlineLabel != null)
            FieldOfflineBanner(
              label: _offlineLabel!,
              hint: offlineListBannerHint(_error),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer ledger', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Line-by-line ledger — separate from Receivables statement and system billing SOA.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  const Text('Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_customerId),
                    initialValue: _customerId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id']?.toString() ?? '',
                            child: Text(c['name']?.toString() ?? 'Customer'),
                          ),
                        )
                        .toList(),
                    onChanged: _fromCache
                        ? null
                        : (value) {
                            setState(() => _customerId = value);
                            _loadLedger();
                          },
                  ),
                  const SizedBox(height: 12),
                  const Text('Date range (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _fromCache ? null : () => _pickDate(isFrom: true),
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text('From: ${_formatDisplayDate(_dateFrom)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _fromCache ? null : () => _pickDate(isFrom: false),
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text('To: ${_formatDisplayDate(_dateTo)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _fromCache || _loadingLedger ? null : _loadLedger,
                    child: Text(_loadingLedger ? 'Loading…' : 'Generate ledger'),
                  ),
                  if (_account != null && customer != null) ...[
                    const SizedBox(height: 8),
                    PrintDocumentButton(
                      onPrint: () => printSoa(customer: customer, account: _account!),
                      label: 'Print ledger PDF',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null && !_fromCache) FieldErrorBanner(message: _error!, onRetry: _loadLedger),
          if (customer != null && totals.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name']?.toString() ?? 'Customer',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text('Debit: ${fieldFormatMoney(totals['totalDebit'])}'),
                    Text('Credit: ${fieldFormatMoney(totals['totalCredit'])}'),
                    Text(
                      'Outstanding: ${fieldFormatMoney(totals['outstanding'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.maroon),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (rows.isEmpty && !_loadingLedger && _error == null && !_fromCache)
            const FieldEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No ledger entries',
              subtitle: 'Select a customer and generate the ledger.',
            ),
          ...rows.map((row) {
            final debit = (row['debit'] as num?)?.toDouble() ?? 0;
            final credit = (row['credit'] as num?)?.toDouble() ?? 0;
            return Card(
              child: ListTile(
                title: Text(row['description']?.toString() ?? row['ref']?.toString() ?? 'Entry'),
                subtitle: Text(row['displayDate']?.toString() ?? row['date']?.toString() ?? '—'),
                trailing: Text(
                  debit > 0 ? fieldFormatMoney(debit) : '- ${fieldFormatMoney(credit)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: debit > 0 ? AppTheme.maroon : AppTheme.successText,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}