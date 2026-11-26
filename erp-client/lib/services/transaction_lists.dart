import 'api_client.dart';
import 'api_errors.dart';
import 'offline_cache.dart';

class TransactionLists {
  static TransactionLists? _memoryCache;
  static DateTime? _memoryCachedAt;
  static Future<TransactionLists>? _loadInFlight;
  static const _memoryTtl = Duration(seconds: 50);

  static void invalidateMemoryCache() {
    _memoryCache = null;
    _memoryCachedAt = null;
  }

  /// Last in-memory workflow lists, else device cache (no network).
  static Future<TransactionLists> peek() async {
    final mem = _memoryCache;
    if (mem != null) return mem;
    return fromCache();
  }

  const TransactionLists({
    this.purchaseOrders = const [],
    this.receivings = const [],
    this.outslips = const [],
    this.deliveryReceipts = const [],
    this.billings = const [],
    this.crossModuleRulesReliable = true,
    this.loadErrors = const [],
  });

  final List<Map<String, dynamic>> purchaseOrders;
  final List<Map<String, dynamic>> receivings;
  final List<Map<String, dynamic>> outslips;
  final List<Map<String, dynamic>> deliveryReceipts;
  final List<Map<String, dynamic>> billings;

  /// False when any list came from cache or failed to load live.
  final bool crossModuleRulesReliable;

  /// Human-readable errors from endpoints that failed (live load).
  final List<String> loadErrors;

  static Future<({List<Map<String, dynamic>> rows, bool live, String? error})> _loadOne(
    ApiClient api,
    String path,
    String cacheKey,
  ) async {
    try {
      final rows = (await api.getList(path)).cast<Map<String, dynamic>>();
      await OfflineCache.saveList(cacheKey, rows);
      return (rows: rows, live: true, error: null);
    } catch (error) {
      final cached = await OfflineCache.loadList(cacheKey);
      return (
        rows: cached.rows,
        live: false,
        error: friendlyApiError(error),
      );
    }
  }

  static Future<TransactionLists> load(
    ApiClient api, {
    bool allowRetry = true,
    bool preferCache = true,
    bool lightSetup = true,
  }) async {
    final now = DateTime.now();
    if (preferCache &&
        _memoryCache != null &&
        _memoryCachedAt != null &&
        now.difference(_memoryCachedAt!) < _memoryTtl) {
      return _memoryCache!;
    }

    if (_loadInFlight != null) {
      return _loadInFlight!;
    }

    _loadInFlight = _loadFresh(api, allowRetry: allowRetry, lightSetup: lightSetup).then((lists) {
      _memoryCache = lists;
      _memoryCachedAt = DateTime.now();
      _loadInFlight = null;
      return lists;
    });

    return _loadInFlight!;
  }

  static Future<TransactionLists> _loadFresh(
    ApiClient api, {
    required bool allowRetry,
    required bool lightSetup,
  }) async {
    await api.ensureConfigured(forceDiscovery: false, light: lightSetup);
    final loaded = await Future.wait([
      _loadOne(api, '/purchase-orders', OfflineCache.purchaseOrders),
      _loadOne(api, '/receivings', OfflineCache.receivings),
      _loadOne(api, '/outslips', OfflineCache.outslips),
      _loadOne(api, '/delivery-receipts', OfflineCache.deliveries),
      _loadOne(api, '/billings', OfflineCache.billings),
    ]);
    final po = loaded[0];
    final rcv = loaded[1];
    final os = loaded[2];
    final dr = loaded[3];
    final bill = loaded[4];

    var live = [po, rcv, os, dr, bill].every((r) => r.live);
    if (!live && allowRetry) {
      final ping = await api.pingHealth(timeout: const Duration(seconds: 3));
      if (ping == null) {
        return _loadFresh(api, allowRetry: false, lightSetup: lightSetup);
      }
    }

    live = [po, rcv, os, dr, bill].every((r) => r.live);
    final errors = <String>[];
    if (!po.live && po.error != null) errors.add(po.error!);
    if (!rcv.live && rcv.error != null) errors.add(rcv.error!);
    if (!os.live && os.error != null) errors.add(os.error!);
    if (!dr.live && dr.error != null) errors.add(dr.error!);
    if (!bill.live && bill.error != null) errors.add(bill.error!);

    return TransactionLists(
      purchaseOrders: po.rows,
      receivings: rcv.rows,
      outslips: os.rows,
      deliveryReceipts: dr.rows,
      billings: bill.rows,
      crossModuleRulesReliable: live,
      loadErrors: errors,
    );
  }

  static Future<TransactionLists> fromCache() async {
    final results = await Future.wait([
      OfflineCache.loadList(OfflineCache.purchaseOrders),
      OfflineCache.loadList(OfflineCache.receivings),
      OfflineCache.loadList(OfflineCache.outslips),
      OfflineCache.loadList(OfflineCache.deliveries),
      OfflineCache.loadList(OfflineCache.billings),
    ]);

    final reliable = results.every((entry) => entry.savedAt != null);

    return TransactionLists(
      purchaseOrders: results[0].rows,
      receivings: results[1].rows,
      outslips: results[2].rows,
      deliveryReceipts: results[3].rows,
      billings: results[4].rows,
      crossModuleRulesReliable: false,
      loadErrors: reliable ? const [] : const ['Using saved lists from this phone.'],
    );
  }
}
