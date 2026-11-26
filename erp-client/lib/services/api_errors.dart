import 'api_client.dart';
import 'api_settings.dart';
import 'offline_cache.dart';

/// Subtitle for [FieldOfflineBanner] when a list fell back to device cache.
String offlineListBannerHint(String? apiError) {
  final lines = <String>[
    OfflineCache.staleDataMismatchNote,
    OfflineCache.offlineReconnectHint,
  ];
  if (apiError != null && apiError.trim().isNotEmpty) {
    lines.insert(0, apiError.trim());
  }
  return lines.join('\n\n');
}

bool isTransientNetworkError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401) return false;
    final message = error.message.toLowerCase();
    return error.statusCode == null ||
        message.contains('socket') ||
        message.contains('failed host') ||
        message.contains('connection') ||
        message.contains('timed out') ||
        message.contains('network error');
  }
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('connection') ||
      text.contains('failed host') ||
      text.contains('timed out') ||
      text.contains('network');
}

String friendlyApiError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == null ||
        error.message.toLowerCase().contains('socket') ||
        error.message.toLowerCase().contains('failed host') ||
        error.message.toLowerCase().contains('connection') ||
        error.message.toLowerCase().contains('timed out')) {
      return _unreachableMessage();
    }
    final msg = error.message;
    if (msg.toLowerCase().contains("unknown column 'barcode'")) {
      return 'This phone still has an old error or wrong server.\n'
          'On the PC: WAMP + npm start in erp-server.\n'
          'In the app: Server → Test (must say node-mobile) → Save & connect → pull to refresh.';
    }
    return msg;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('failed host') ||
      text.contains('timed out') ||
      text.contains('network')) {
    return _unreachableMessage();
  }
  return 'Something went wrong.';
}

String _unreachableMessage() {
  final base = ApiSettings.current;
  if (base.contains('10.0.2.2')) {
    return 'Cannot reach API at $base.\n'
        '1) Start MySQL (WAMP) with database rts_system\n'
        '2) In erp-server run: npm start\n'
        'On a physical phone, tap Server on login and enter your PC LAN IP (e.g. 192.168.1.10:8000).';
  }
  if (base.contains('127.0.0.1') || base.contains('localhost')) {
    return 'Cannot reach API at $base.\n'
        '1) Start MySQL (WAMP)\n'
        '2) In C:\\ERP-System-main\\erp-server run: npm start\n'
        '3) Hot restart the app (press R in the Flutter terminal)';
  }
  return 'Cannot reach API at $base.\n'
      '1) On the PC: cd erp-server && npm start\n'
      '2) Same Wi‑Fi as the phone; allow port 8000 in Windows Firewall\n'
      '3) Login → Server → your PC IP:8000 → Test connection';
}
