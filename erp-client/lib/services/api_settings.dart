// C:\ERP-System-main\erp-client\lib\services\api_settings.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves API base URL from a saved host (and optional port) on the device.
///
/// UI stores: `192.168.1.60:8000` or `192.168.1.60`
/// Requests use: `http://{host}:{port}/api/mobile/...`
class ApiSettings {
  ApiSettings._();

  static const _prefKey = 'rc_api_server_host';

  /// Legacy key (full URL with path) — migrated on [load].
  static const _legacyPrefKey = 'rc_api_base_url';

  static const defaultPort = 8000;

  static const String _dartDefineDefault = String.fromEnvironment('API_BASE_URL');

  static String get builtinDefault {
    if (_dartDefineDefault.isNotEmpty) return _dartDefineDefault;
    if (dotenv.isInitialized) {
      final envUrl = dotenv.maybeGet('API_URL')?.trim();
      if (envUrl != null && envUrl.isNotEmpty) {
        return normalizeApiBase(envUrl);
      }
    }
    return 'http://10.0.2.2:8000/api/mobile';
  }

  static String _current = _apiBaseFromHostPort(_hostPortFromApiBase(builtinDefault));

  /// Full base including path, e.g. `http://192.168.1.60:8000/api/mobile`
  static String get current => _current;

  /// Saved host for UI, e.g. `192.168.1.60:8000`
  static String get savedHostPort => _hostPortFromApiBase(_current);

  static Future<void> load() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    var hostPort = prefs.getString(_prefKey);
    if (hostPort == null || hostPort.trim().isEmpty) {
      final legacy = prefs.getString(_legacyPrefKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        hostPort = _hostPortFromApiBase(normalizeApiBase(legacy));
        await prefs.setString(_prefKey, hostPort);
        await prefs.remove(_legacyPrefKey);
      }
    }
    if (hostPort == null || hostPort.trim().isEmpty) {
      hostPort = _hostPortFromApiBase(builtinDefault);
    }
    _current = _apiBaseFromHostPort(normalizeHostPort(hostPort));
  }

  /// [input] is host, host:port, or legacy full URL — only host:port is persisted.
  static Future<void> save(String input) async {
    final hostPort = normalizeHostPort(input);
    _current = _apiBaseFromHostPort(hostPort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, hostPort);
    await prefs.remove(_legacyPrefKey);
  }

  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_legacyPrefKey);
    _current = _apiBaseFromHostPort(_hostPortFromApiBase(builtinDefault));
  }

  /// Accepts host, host:port, or legacy URL → host:port (no scheme, no path).
  static String normalizeHostPort(String raw) {
    var text = raw.trim();
    if (text.isEmpty) {
      return _hostPortFromApiBase(builtinDefault);
    }
    if (text.contains('://')) {
      final uri = Uri.tryParse(text);
      if (uri != null && uri.host.isNotEmpty) {
        final port = uri.hasPort ? uri.port : defaultPort;
        return '${uri.host}:$port';
      }
    }
    text = text.replaceAll(RegExp(r'/+$'), '');
    final pathIdx = text.indexOf('/');
    if (pathIdx > 0) {
      text = text.substring(0, pathIdx);
    }
    if (!text.contains(':')) {
      return '$text:$defaultPort';
    }
    final parts = text.split(':');
    if (parts.length == 2 && int.tryParse(parts[1]) != null) {
      return text;
    }
    return '$text:$defaultPort';
  }

  /// Builds request base URL from host:port or legacy input.
  static String normalize(String raw) => _apiBaseFromHostPort(normalizeHostPort(raw));

  static String normalizeApiBase(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return normalize(builtinDefault);
    if (!url.contains('://')) {
      return normalize(url);
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    final lower = url.toLowerCase();
    if (lower.endsWith('/api/mobile')) return url;
    if (lower.endsWith('/api')) return '$url/mobile';
    return '$url/api/mobile';
  }

  static String _apiBaseFromHostPort(String hostPort) {
    final hp = normalizeHostPort(hostPort);
    return 'http://$hp/api/mobile';
  }

  static String _apiBaseFromApiBase(String apiBase) =>
      normalizeApiBase(apiBase);

  static String _hostPortFromApiBase(String apiBase) {
    final uri = Uri.tryParse(normalizeApiBase(apiBase));
    if (uri == null || uri.host.isEmpty) {
      return '10.0.2.2:$defaultPort';
    }
    final port = uri.hasPort ? uri.port : defaultPort;
    return '${uri.host}:$port';
  }

  /// Login / Server row label: `192.168.1.60:8000` (no scheme, no path).
  static String displayHostPort(String baseUrl) => savedHostPortFrom(baseUrl);

  static String savedHostPortFrom(String baseUrl) =>
      normalizeHostPort(_hostPortFromApiBase(normalizeApiBase(baseUrl)));
}