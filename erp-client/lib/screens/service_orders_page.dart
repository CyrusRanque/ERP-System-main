import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/transaction_actions.dart';
import '../state/auth_state.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../services/service_order_pdf.dart';
import '../theme/app_theme.dart';
import '../widgets/field_ui.dart';

const _saleTypes = ['Charge Sales', 'Cash Sales'];

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class ServiceOrdersPage extends StatefulWidget {
  const ServiceOrdersPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ServiceOrdersPage> createState() => _ServiceOrdersPageState();
}

class _ServiceOrdersPageState extends State<ServiceOrdersPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  bool _saving = false;
  bool _fromCache = false;
  String? _error;
  String? _offlineLabel;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _projects = [];
  String? _nextInvoiceNo;

  String? _customerId;
  String? _projectId;
  String _saleType = _saleTypes.first;
  DateTime _transactionDate = DateTime.now();

  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController(text: '0.00');
  final _searchController = TextEditingController();

  String _statusFilter = 'all';
  String? _busyRowId;

  int get _pendingCount => _rows.where((r) => r['status']?.toString() == 'pending').length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _hydrateFromCache();
    if (!mounted) return;
    await _load(silent: _rows.isNotEmpty || _customers.isNotEmpty);
  }

  Future<void> _hydrateFromCache() async {
    final cached = await Future.wait([
      OfflineCache.loadList(OfflineCache.serviceOrders),
      OfflineCache.loadList(OfflineCache.serviceOrderCustomers),
      OfflineCache.loadList(OfflineCache.serviceOrderProjects),
      OfflineCache.loadMap(OfflineCache.serviceOrderMeta),
    ]);
    final orders = cached[0] as ({List<Map<String, dynamic>> rows, DateTime? savedAt});
    final customers = cached[1] as ({List<Map<String, dynamic>> rows, DateTime? savedAt});
    final projects = cached[2] as ({List<Map<String, dynamic>> rows, DateTime? savedAt});
    final meta = cached[3] as ({Map<String, dynamic>? data, DateTime? savedAt});
    if (!mounted) return;
    if (orders.rows.isEmpty && customers.rows.isEmpty) return;
    setState(() {
      _rows = orders.rows;
      _customers = customers.rows.where(fieldSetupRowIsActive).toList();
      _projects = projects.rows.where(fieldSetupRowIsActive).toList();
      _nextInvoiceNo = meta.data?['nextInvoiceNo']?.toString() ?? _nextInvoiceNo ?? '0001';
      _customerId ??=
          _customers.isNotEmpty ? _customers.first['id']?.toString() : null;
      _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _statusFilteredRows {
    switch (_statusFilter) {
      case 'pending':
        return _rows.where((r) => r['status']?.toString() == 'pending').toList();
      case 'approved':
        return _rows.where((r) => r['status']?.toString() == 'approved').toList();
      default:
        return _rows;
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    final base = _statusFilteredRows;
    if (query.isEmpty) return base;
    return base.where((row) {
      final blob = [
        row['invoiceNo'],
        row['id'],
        row['customerName'],
        row['projectName'],
        row['description'],
        row['date'],
        row['displayDate'],
        row['amount'],
      ].map((v) => v?.toString() ?? '').join(' ').toLowerCase();
      return blob.contains(query);
    }).toList();
  }

  static String formatServiceOrderListDate(dynamic raw) {
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw.toString().split(RegExp(r'\s')).first);
    if (parsed == null) return raw.toString();
    return '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static String formatServiceOrderAmount(dynamic raw) {
    final amount = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0;
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  String _formatApiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load({bool silent = false}) async {
    final wasOffline = _fromCache;
    final hasData = _rows.isNotEmpty || _customers.isNotEmpty;
    final blockUi = !silent && !hasData;
    setState(() {
      _loading = blockUi;
      if (!silent) {
        _error = null;
        _fromCache = false;
        _offlineLabel = null;
      }
    });

    try {
      await widget.api.ensureConfigured();
      final results = await Future.wait([
        widget.api.request('GET', '/service-orders'),
        widget.api.getList('/setup/customers'),
        widget.api.getList('/setup/projects'),
      ]);
      final indexPayload = Map<String, dynamic>.from(results[0] as Map);
      final orders = (indexPayload['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final customers = results[1].cast<Map<String, dynamic>>();
      final projects = results[2].cast<Map<String, dynamic>>();
      final nextInvoice = indexPayload['nextInvoiceNo']?.toString() ?? '0001';

      if (!mounted) return;
      setState(() {
        _rows = orders;
        _customers = customers.where(fieldSetupRowIsActive).toList();
        _projects = projects.where(fieldSetupRowIsActive).toList();
        _nextInvoiceNo = nextInvoice;
        _customerId ??=
            _customers.isNotEmpty ? _customers.first['id']?.toString() : null;
        _projectId ??= _projects.isNotEmpty ? _projects.first['id']?.toString() : null;
        _loading = false;
        _fromCache = false;
        _offlineLabel = null;
        _error = null;
      });
      unawaited(
        Future.wait([
          OfflineCache.saveList(OfflineCache.serviceOrders, orders),
          OfflineCache.saveList(OfflineCache.serviceOrderCustomers, customers),
          OfflineCache.saveList(OfflineCache.serviceOrderProjects, projects),
          OfflineCache.saveMap(OfflineCache.serviceOrderMeta, {'nextInvoiceNo': nextInvoice}),
        ]),
      );
      if (wasOffline && mounted) fieldShowBackOnlineSnackBar(context);
    } catch (error) {
      final cached = await OfflineCache.loadList(OfflineCache.serviceOrders);
      final cachedCustomers = await OfflineCache.loadList(OfflineCache.serviceOrderCustomers);
      final cachedProjects = await OfflineCache.loadList(OfflineCache.serviceOrderProjects);
      if (!mounted) return;
      if (cached.rows.isNotEmpty || cachedCustomers.rows.isNotEmpty) {
        setState(() {
          _rows = cached.rows;
          _customers = cachedCustomers.rows.where(fieldSetupRowIsActive).toList();
          _projects = cachedProjects.rows.where(fieldSetupRowIsActive).toList();
          _fromCache = true;
          _offlineLabel = OfflineCache.staleLabel(cached.savedAt);
          _error = friendlyApiError(error);
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

  Future<void> _pickDate() async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _transactionDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving || _fromCache) {
      if (_fromCache) fieldShowOfflineBlocked(context);
      return;
    }
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer.')),
      );
      return;
    }

    fieldFormatMoneyController(_unitCostController);
    final qty = double.tryParse(_quantityController.text.trim());
    final unitCost = double.tryParse(_unitCostController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity.')),
      );
      return;
    }
    if (unitCost == null || unitCost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid unit cost.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = await widget.api.post('/service-orders', {
        'customerId': int.tryParse(customerId) ?? customerId,
        'projectId': _projectId != null ? (int.tryParse(_projectId!) ?? _projectId) : null,
        'description': _descriptionController.text.trim(),
        'date': _formatApiDate(_transactionDate),
        'saleType': _saleType,
        'quantity': qty,
        'unitCost': unitCost,
      });
      if (!mounted) return;
      final saved = payload['data'];
      final savedRow = saved is Map ? Map<String, dynamic>.from(saved) : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(payload['message']?.toString() ?? 'Saved.')),
      );
      _descriptionController.clear();
      _quantityController.text = '1';
      _unitCostController.text = '0.00';
      setState(() {
        _nextInvoiceNo = payload['nextInvoiceNo']?.toString() ?? _nextInvoiceNo;
      });
      await _load(silent: true);
      if (!mounted) return;
      _tabController.animateTo(1);
      if (savedRow != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOrderDetailSheet(savedRow);
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rejectOrder(Map<String, dynamic> row) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final id = fieldRowId(row);
    if (id.isEmpty || _busyRowId != null) return;
    if (row['status']?.toString() != 'pending') return;
    final invoice = row['invoiceNo']?.toString() ?? row['id']?.toString() ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject service order?'),
        content: Text('Invoice $invoice will be rejected and removed from the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.maroon),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyRowId = id);
    try {
      final response = await widget.api.post('/service-orders/${Uri.encodeComponent(id)}/reject', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Rejected.')),
      );
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  Future<void> _approveOrder(Map<String, dynamic> row) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final id = fieldRowId(row);
    if (id.isEmpty || _busyRowId != null) return;
    if (row['status']?.toString() != 'pending') return;

    setState(() => _busyRowId = id);
    try {
      final response = await widget.api.post('/service-orders/${Uri.encodeComponent(id)}/approve', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Approved.')),
      );
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  Future<void> _voidOrder(Map<String, dynamic> row) async {
    if (_fromCache) {
      fieldShowOfflineBlocked(context);
      return;
    }
    final id = fieldRowId(row);
    if (id.isEmpty || _busyRowId != null) return;
    final invoice = row['invoiceNo']?.toString() ?? row['id']?.toString() ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void service order?'),
        content: Text('Invoice $invoice will be voided and removed from active lists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.maroon),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyRowId = id);
    try {
      await widget.api.post('/service-orders/${Uri.encodeComponent(id)}/void', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service order voided.')));
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  Future<void> _printOrder(Map<String, dynamic> row) async {
    final id = fieldRowId(row);
    if (id.isEmpty || _busyRowId != null) return;

    setState(() => _busyRowId = id);
    try {
      final customerId = row['customerId']?.toString();
      Map<String, dynamic>? customer;
      if (customerId != null) {
        for (final c in _customers) {
          if (c['id']?.toString() == customerId) {
            customer = c;
            break;
          }
        }
      }
      await ServiceOrderPdf.share(row, customer: customer);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare printout: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyRowId = null);
    }
  }

  void _showOrderDetailSheet(Map<String, dynamic> row) {
    final isAdmin = userIsAdmin(context.read<AuthState>().user);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
          child: _ServiceOrderDetailSheet(
            row: row,
            isAdmin: isAdmin,
            offline: _fromCache,
            busy: _busyRowId == fieldRowId(row),
            formatDate: formatServiceOrderListDate,
            formatAmount: formatServiceOrderAmount,
            onApprove: () {
              Navigator.pop(sheetContext);
              _approveOrder(row);
            },
            onReject: () {
              Navigator.pop(sheetContext);
              _rejectOrder(row);
            },
            onPrint: () {
              Navigator.pop(sheetContext);
              _printOrder(row);
            },
            onVoid: () {
              Navigator.pop(sheetContext);
              _voidOrder(row);
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusBanners() {
    return Column(
      children: [
        if (_fromCache && _offlineLabel != null)
          FieldOfflineBanner(
            label: _offlineLabel!,
            hint: offlineListBannerHint(_error),
          ),
        if (_error != null && !_fromCache)
          FieldErrorBanner(message: _error!, onRetry: _load),
      ],
    );
  }

  Widget _buildNewTab() {
    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusBanners(),
          _EntryFormCard(
            customers: _customers,
            projects: _projects,
            customerId: _customerId,
            projectId: _projectId,
            saleType: _saleType,
            transactionDate: _transactionDate,
            invoiceNo: _nextInvoiceNo ?? '—',
            descriptionController: _descriptionController,
            quantityController: _quantityController,
            unitCostController: _unitCostController,
            saving: _saving,
            onCustomerChanged: (v) => setState(() => _customerId = v),
            onProjectChanged: (v) => setState(() => _projectId = v),
            onSaleTypeChanged: (v) => setState(() => _saleType = v ?? _saleTypes.first),
            onPickDate: _pickDate,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    final rows = _filteredRows;
    final isAdmin = userIsAdmin(context.watch<AuthState>().user);
    final pendingLabel = _pendingCount > 0 ? 'Pending ($_pendingCount)' : 'Pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              _buildStatusBanners(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  final colors = AppTheme.resolve(context);
                  return TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search invoice or customer',
                      prefixIcon: const Icon(Icons.search, size: 22),
                      filled: true,
                      fillColor: colors.surface,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear',
                              onPressed: _searchController.clear,
                            ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
              const SizedBox(height: 8),
              FieldFilterBar(
                value: _statusFilter,
                options: [
                  (id: 'all', label: 'All'),
                  (id: 'pending', label: pendingLabel),
                  (id: 'approved', label: 'Approved'),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.maroon,
            onRefresh: () => _load(silent: true),
            child: _rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 48),
                      FieldEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No service orders yet',
                        subtitle: 'Open the New tab to create one.',
                      ),
                    ],
                  )
                : rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 48),
                          FieldEmptyState(
                            icon: _statusFilter == 'pending'
                                ? Icons.task_alt_outlined
                                : Icons.search_off_outlined,
                            title: _rows.isEmpty ? 'No service orders yet' : 'Nothing here',
                            subtitle: _rows.isEmpty
                                ? 'Open the New tab to create one.'
                                : _statusFilter == 'pending'
                                    ? 'No orders waiting for approval.'
                                    : 'Try another filter or search term.',
                          ),
                          if (_rows.isNotEmpty && _statusFilter == 'pending') ...[
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() => _statusFilter = 'approved'),
                                child: const Text('View approved orders'),
                              ),
                            ),
                          ],
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final status = row['status']?.toString() ?? '';
                          final showApprove = isAdmin && status == 'pending';
                          final busy = _busyRowId == fieldRowId(row);
                          return _ServiceOrderCompactTile(
                            row: row,
                            formatDate: formatServiceOrderListDate,
                            formatAmount: formatServiceOrderAmount,
                            showApprove: showApprove,
                            approving: busy,
                            onApprove: () => _approveOrder(row),
                            onReject: () => _rejectOrder(row),
                            onTap: () => _showOrderDetailSheet(row),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty && _customers.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final savedTabLabel = _rows.isEmpty
        ? 'Saved'
        : _pendingCount > 0
            ? 'Saved (${_rows.length})'
            : 'Saved (${_rows.length})';

    final colors = AppTheme.resolve(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surface,
          elevation: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? Colors.white : AppTheme.maroon,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: isDark ? AppTheme.brandOrange : AppTheme.maroon,
              indicatorWeight: 3,
              tabs: [
              const Tab(text: 'New'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(savedTabLabel),
                    if (_pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warningText.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_pendingCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warningText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNewTab(),
              _buildSavedTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryFormCard extends StatelessWidget {
  const _EntryFormCard({
    required this.customers,
    required this.projects,
    required this.customerId,
    required this.projectId,
    required this.saleType,
    required this.transactionDate,
    required this.invoiceNo,
    required this.descriptionController,
    required this.quantityController,
    required this.unitCostController,
    required this.saving,
    required this.onCustomerChanged,
    required this.onProjectChanged,
    required this.onSaleTypeChanged,
    required this.onPickDate,
    required this.onSave,
  });

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> projects;
  final String? customerId;
  final String? projectId;
  final String saleType;
  final DateTime transactionDate;
  final String invoiceNo;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final bool saving;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onSaleTypeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  String _formatDisplayDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')} / ${date.day.toString().padLeft(2, '0')} / ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: customerId,
              decoration: _fieldDecoration('Customer'),
              items: customers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id']?.toString(),
                      child: Text(c['name']?.toString() ?? 'Customer', overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onCustomerChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: projectId,
              decoration: _fieldDecoration('Project'),
              items: projects
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id']?.toString(),
                      child: Text(p['name']?.toString() ?? 'Project', overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onProjectChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: _fieldDecoration('Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onPickDate,
              child: InputDecorator(
                decoration: _fieldDecoration('Date'),
                child: Text(_formatDisplayDate(transactionDate)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: saleType,
              decoration: _fieldDecoration('Sale type'),
              items: _saleTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: onSaleTypeChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: _fieldDecoration('Quantity'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FieldMoneyTextField(
                    controller: unitCostController,
                    decoration: _fieldDecoration('Unit cost'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: _fieldDecoration('Invoice no.'),
              child: Text(invoiceNo, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.maroon),
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOrderCompactTile extends StatelessWidget {
  const _ServiceOrderCompactTile({
    required this.row,
    required this.formatDate,
    required this.formatAmount,
    required this.showApprove,
    required this.approving,
    required this.onApprove,
    required this.onReject,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) formatAmount;
  final bool showApprove;
  final bool approving;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.resolve(context);
    final invoice = row['invoiceNo']?.toString() ?? row['id']?.toString() ?? '—';
    final customer = row['customerName']?.toString() ?? '—';
    final project = row['projectName']?.toString() ?? '';
    final status = row['status']?.toString();
    final date = formatDate(row['displayDate'] ?? row['date']);
    final amount = formatAmount(row['amount']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        invoice,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      amount,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.brandOrange
                            : AppTheme.maroon,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 22, color: colors.textSecondary),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FieldStatusChip(status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        date,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (project.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    project,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
                if (showApprove) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: approving ? null : onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: FilledButton(
                            onPressed: approving ? null : onApprove,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.maroon,
                            ),
                            child: Text(approving ? '…' : 'Approve'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceOrderDetailSheet extends StatelessWidget {
  const _ServiceOrderDetailSheet({
    required this.row,
    required this.isAdmin,
    required this.offline,
    required this.busy,
    required this.formatDate,
    required this.formatAmount,
    required this.onApprove,
    required this.onReject,
    required this.onPrint,
    required this.onVoid,
  });

  final Map<String, dynamic> row;
  final bool isAdmin;
  final bool offline;
  final bool busy;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) formatAmount;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPrint;
  final VoidCallback onVoid;

  bool get _isPending => row['status']?.toString() == 'pending';
  bool get _isApproved => row['status']?.toString() == 'approved';

  @override
  Widget build(BuildContext context) {
    final invoice = row['invoiceNo']?.toString() ?? row['id']?.toString() ?? '—';
    final customer = row['customerName']?.toString() ?? '—';
    final project = row['projectName']?.toString() ?? '—';
    final rawDesc = row['description']?.toString().trim() ?? '';
    final description = rawDesc.isEmpty ? null : rawDesc;
    final date = formatDate(row['displayDate'] ?? row['date']);
    final amount = formatAmount(row['amount']);
    final saleType = row['saleType']?.toString();
    final qty = row['quantity'];
    final unitCost = row['unitCost'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invoice $invoice',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FieldStatusChip(row['status']?.toString()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.maroon,
            ),
          ),
          if (_isPending) ...[
            const SizedBox(height: 8),
            const Text(
              'Waiting for manager approval before this is treated as final.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          _SheetDetailLine(label: 'Date', value: date),
          _SheetDetailLine(label: 'Customer', value: customer),
          _SheetDetailLine(label: 'Project', value: project),
          if (description != null) _SheetDetailLine(label: 'Description', value: description),
          if (saleType != null && saleType.isNotEmpty)
            _SheetDetailLine(label: 'Sale type', value: saleType),
          if (qty != null) _SheetDetailLine(label: 'Quantity', value: qty.toString()),
          if (unitCost != null)
            _SheetDetailLine(label: 'Unit cost', value: formatAmount(unitCost)),
          const SizedBox(height: 20),
          if (busy)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else ...[
            if (isAdmin && _isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: offline ? null : onReject,
                      icon: Icon(Icons.close, color: Colors.red.shade700),
                      label: Text('Reject', style: TextStyle(color: Colors.red.shade700)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: offline ? null : onApprove,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_isApproved)
              FilledButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.maroon,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppTheme.maroon),
                ),
              ),
            if (isAdmin && _isApproved) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: offline ? null : onVoid,
                icon: Icon(Icons.block, color: Colors.red.shade700),
                label: Text('Void', style: TextStyle(color: Colors.red.shade700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SheetDetailLine extends StatelessWidget {
  const _SheetDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, height: 1.35)),
        ],
      ),
    );
  }
}
