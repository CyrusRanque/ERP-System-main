import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../services/api_client.dart';
import '../services/api_errors.dart';
import '../services/offline_cache.dart';
import '../services/transaction_lists.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final ApiClient api;

  bool bootstrapping = true;
  bool busy = false;
  String? error;

  bool get isAuthenticated => api.isAuthenticated;
  Map<String, dynamic>? get user => api.user;

  /// Updates session/API after user changes server URL (no full-app splash).
  Future<void> refreshAfterServerChange() async {
    error = null;
    try {
      await api.ensureConfigured(forceDiscovery: true);
      if (api.isAuthenticated) {
        await api.me();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        error = friendlyApiError(e);
        await api.clearSession();
      } else if (!isTransientNetworkError(e)) {
        error = friendlyApiError(e);
      }
    } catch (e) {
      if (!isTransientNetworkError(e)) {
        error = friendlyApiError(e);
      }
    }
    // Defer so callers (e.g. server sheet) can finish route dispose first.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> bootstrap() async {
    bootstrapping = true;
    error = null;
    notifyListeners();

    try {
      await api.ensureConfigured(forceDiscovery: true);
      await api.restoreSession();
      if (api.isAuthenticated) {
        await api.me();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        error = friendlyApiError(e);
        await api.clearSession();
      } else if (isTransientNetworkError(e)) {
        // Keep session; dashboard can use cached data until API is back.
        error = null;
      } else {
        error = friendlyApiError(e);
        await api.clearSession();
      }
    } catch (e) {
      if (isTransientNetworkError(e)) {
        error = null;
      } else {
        error = friendlyApiError(e);
        await api.clearSession();
      }
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login(String login, String password) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      await api.ensureConfigured(forceDiscovery: true);
      await api.login(login.trim(), password);
      await OfflineCache.clearAll();
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = friendlyApiError(e);
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    busy = true;
    error = null;
    notifyListeners();
    await api.logout();
    TransactionLists.invalidateMemoryCache();
    busy = false;
    notifyListeners();
  }

  void handleSessionExpired(String message) {
    error = message;
    busy = false;
    bootstrapping = false;
    notifyListeners();
  }
}
