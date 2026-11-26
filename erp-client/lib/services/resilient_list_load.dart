import 'api_client.dart';
import 'api_errors.dart';
import 'offline_cache.dart';
import 'transaction_lists.dart';

/// Result of loading a module list plus cross-module workflow data.
class ResilientListLoadResult {
  const ResilientListLoadResult({
    required this.rows,
    required this.lists,
    this.fromCache = false,
    this.offlineLabel,
    this.primaryError,
    this.workflowError,
  });

  final List<Map<String, dynamic>> rows;
  final TransactionLists lists;
  final bool fromCache;
  final String? offlineLabel;
  final String? primaryError;
  final String? workflowError;
}

class CachedListPreview {
  const CachedListPreview({
    required this.rows,
    required this.lists,
    this.offlineLabel,
  });

  final List<Map<String, dynamic>> rows;
  final TransactionLists lists;
  final String? offlineLabel;
}

/// Last saved primary list + workflow cache on this device (no network).
///
/// Use before [loadResilientTransactionList] for fast first paint only — do **not**
/// set offline UI from [CachedListPreview.offlineLabel] until a network refresh fails.
Future<CachedListPreview?> readCachedTransactionList(String cacheKey) async {
  final cached = await OfflineCache.loadList(cacheKey);
  if (cached.rows.isEmpty) return null;
  final lists = await TransactionLists.peek();
  return CachedListPreview(
    rows: cached.rows,
    lists: lists,
    offlineLabel: OfflineCache.staleLabel(cached.savedAt),
  );
}

/// Loads primary list from API when possible; workflow lists are best-effort.
Future<ResilientListLoadResult> loadResilientTransactionList({
  required ApiClient api,
  required String cacheKey,
  required Future<List<dynamic>> Function() fetchPrimary,
  bool loadWorkflowLists = true,
}) async {
  await api.ensureConfigured(light: true);

  final listsFuture = loadWorkflowLists
      ? TransactionLists.load(api, lightSetup: true)
      : null;

  TransactionLists lists = const TransactionLists(crossModuleRulesReliable: false);
  Object? workflowError;

  Future<List<dynamic>> fetchWithRetry() async {
    try {
      return await fetchPrimary();
    } catch (error) {
      if (!isTransientNetworkError(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return await fetchPrimary();
    }
  }

  try {
    final data = await fetchWithRetry();
    if (listsFuture != null) {
      try {
        lists = await listsFuture;
      } catch (error) {
        workflowError = error;
        lists = await TransactionLists.fromCache();
      }
    }
    await OfflineCache.saveList(cacheKey, data);
    return ResilientListLoadResult(
      rows: data.cast<Map<String, dynamic>>(),
      lists: lists,
      workflowError: workflowError != null ? friendlyApiError(workflowError) : null,
    );
  } catch (error) {
    if (listsFuture != null) {
      try {
        lists = await listsFuture;
      } catch (workflowErr) {
        workflowError ??= workflowErr;
        lists = await TransactionLists.fromCache();
      }
    }
    final cached = await OfflineCache.loadList(cacheKey);
    if (cached.rows.isNotEmpty) {
      return ResilientListLoadResult(
        rows: cached.rows,
        lists: lists,
        fromCache: true,
        offlineLabel: OfflineCache.staleLabel(cached.savedAt),
        primaryError: friendlyApiError(error),
        workflowError: workflowError != null ? friendlyApiError(workflowError) : null,
      );
    }
    return ResilientListLoadResult(
      rows: const [],
      lists: lists,
      primaryError: friendlyApiError(error),
      workflowError: workflowError != null ? friendlyApiError(workflowError) : null,
    );
  }
}

String? resilientListBannerHint(ResilientListLoadResult result) {
  if (result.fromCache) {
    return offlineListBannerHint(result.primaryError ?? result.workflowError);
  }
  if (result.workflowError != null) {
    return offlineListBannerHint(result.workflowError);
  }
  return null;
}
