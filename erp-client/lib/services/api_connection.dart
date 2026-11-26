import 'api_settings.dart';
import 'api_discovery.dart';
import 'api_lan_scan.dart';

/// LAN-first fallbacks (classic field app). USB/emulator last.
const kApiFallbackHostPorts = [
  '10.0.2.2:8000',
  '127.0.0.1:8000',
];

typedef HealthPing = Future<String?> Function({
  String? baseUrlOverride,
  Duration timeout,
});

/// Finds a reachable API base and updates saved host:port when the PC IP changed.
Future<String?> resolveReachableApiBase({
  required HealthPing pingHealth,
  String? savedBase,
  Duration timeout = const Duration(seconds: 3),
  bool deepDiscovery = true,
}) async {
  final saved = ApiSettings.normalize(savedBase ?? ApiSettings.current);
  if (await pingHealth(baseUrlOverride: saved, timeout: timeout) == null) {
    return saved;
  }

  if (!deepDiscovery) {
    return null;
  }

  final discovered = await ApiDiscovery.discover(timeout: const Duration(seconds: 3));
  if (discovered != null &&
      await pingHealth(baseUrlOverride: discovered, timeout: timeout) == null) {
    return discovered;
  }

  final scanned = await scanLanForMobileApi(
    pingHealth: pingHealth,
    hostTimeout: const Duration(milliseconds: 700),
  );
  if (scanned != null &&
      await pingHealth(baseUrlOverride: scanned, timeout: timeout) == null) {
    return scanned;
  }

  for (final hostPort in kApiFallbackHostPorts) {
    final normalized = ApiSettings.normalize(hostPort);
    if (normalized == saved) continue;
    if (await pingHealth(baseUrlOverride: normalized, timeout: timeout) == null) {
      return normalized;
    }
  }

  return null;
}

/// Persists discovered base as host:port only.
Future<void> applyResolvedApiBase(String apiBase) async {
  await ApiSettings.save(ApiSettings.savedHostPortFrom(apiBase));
}
