import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

class _AgingBucket {
  const _AgingBucket(this.label, this.minDays, this.maxDays);

  final String label;
  final int minDays;
  final int? maxDays;
}

const _buckets = <_AgingBucket>[
  _AgingBucket('Current (0–30 days)', 0, 30),
  _AgingBucket('31–60 days', 31, 60),
  _AgingBucket('61–90 days', 61, 90),
  _AgingBucket('Over 90 days', 91, null),
];

class ArAgingPage extends StatefulWidget {
  const ArAgingPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ArAgingPage> createState() => _ArAgingPageState();
}

class _ArAgingPageState extends State<ArAgingPage> {
  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  String? _offlineLabel;
  List<Map<String, dynamic>> _rows = [];

  DateTime? _parseDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.split(' ').first);
  }

  int _daysAged(DateTime billingDate, DateTime asOf) {
    return asOf.difference(DateTime(billingDate.year, billingDate.month, billingDate.day)).inDays;
  }

  _AgingBucket _bucketForDays(int days) {
    for (final bucket in _buckets) {
      if (bucket.maxDays == null) {
        if (days >= bucket.minDays) return bucket;
      } else if (days >= bucket.minDays && days <= bucket.maxDays!) {
        return bucket;
      }
    }
    return _buckets.last;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _fromCache = false;
      _offlineLabel = null;
    });

    try {
      await widget.api.ensureConfigured();
      final data = await widget.api.getList('/billings', query: const {'all': '1'});
      final rows = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      await OfflineCache.saveList(OfflineCache.billings, rows);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.billings);
      if (!mounted) return;
      if (cached.rows.isNotEmpty) {
        setState(() {
          _rows = cached.rows;
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final asOf = DateTime.now();
    final open = _rows.where((r) => r['paymentStatus']?.toString() != 'paid').toList();

    final grouped = <_AgingBucket, List<Map<String, dynamic>>>{
      for (final b in _buckets) b: [],
    };

    num totalOutstanding = 0;
    for (final row in open) {
      final balance = fieldBillingBalanceDue(row).toDouble();
      if (balance <= 0) continue;
      final billed = _parseDate(row['billingDate'] ?? row['billing_date'] ?? row['date']);
      final days = billed != null ? _daysAged(billed, asOf) : 0;
      final bucket = _bucketForDays(days);
      grouped[bucket]!.add(row);
      totalOutstanding += balance;
    }

    return RefreshIndicator(
      onRefresh: _load,
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
          if (_error != null && !_fromCache) FieldErrorBanner(message: _error!, onRetry: _load),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AR Aging',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open billings as of ${_formatApiDate(asOf)} · ${open.length} open',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total outstanding: ${fieldFormatMoney(totalOutstanding)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.maroon,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open.isEmpty && _error == null)
            const FieldEmptyState(
              icon: Icons.hourglass_empty_outlined,
              title: 'No open receivables',
              subtitle: 'All billing statements are paid.',
            ),
          ..._bucketSections(grouped, asOf),
        ],
      ),
    );
  }

  String _formatApiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Widget> _bucketSections(
    Map<_AgingBucket, List<Map<String, dynamic>>> grouped,
    DateTime asOf,
  ) {
    final widgets = <Widget>[];
    for (final bucket in _buckets) {
      final items = grouped[bucket]!;
      if (items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            bucket.label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      );
      for (final row in items) {
        final balance = fieldBillingBalanceDue(row);
        final billed = _parseDate(row['billingDate'] ?? row['billing_date'] ?? row['date']);
        final days = billed != null ? _daysAged(billed, asOf) : 0;
        final customer = row['customerName']?.toString() ?? row['customer']?.toString() ?? 'Customer';
        widgets.add(
          Card(
            child: ListTile(
              title: Text(row['id']?.toString() ?? 'Billing'),
              subtitle: Text('$customer · $days days · ${row['displayDate'] ?? row['billingDate'] ?? '—'}'),
              trailing: Text(
                fieldFormatMoney(balance),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.maroon),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}