import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_connection.dart';
import 'api_settings.dart';
import 'offline_cache.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient();

  static const _requestTimeout = Duration(seconds: 30);

  static const _tokenKey = 'rc_erp_token';
  static const _userKey = 'rc_erp_user';

  /// Called when the server rejects the session (401). Wire to [AuthState].
  void Function(String message)? onSessionExpired;

  String? _token;
  Map<String, dynamic>? _user;

  bool _settingsLoaded = false;
  DateTime? _lastReachableAt;
  bool _discoveryRunning = false;
  Future<void>? _discoveryFuture;

  /// After a successful API call we skip LAN discovery for this long.
  static const _discoveryCooldown = Duration(minutes: 15);

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  String get baseUrl => ApiSettings.current;

  /// Loads saved server URL. [forceDiscovery] runs LAN/USB discovery (login, server settings).
  /// [light] skips LAN discovery during routine screen loads (faster browsing).
  Future<void> ensureConfigured({bool forceDiscovery = false, bool light = false}) async {
    if (!_settingsLoaded) {
      await ApiSettings.load();
      _settingsLoaded = true;
    }

    if (light && !forceDiscovery) {
      return;
    }

    final needsDiscovery = forceDiscovery || !_withinDiscoveryCooldown;
    if (!needsDiscovery) {
      return;
    }

    if (_discoveryRunning && _discoveryFuture != null) {
      return _discoveryFuture;
    }

    final deepDiscovery = forceDiscovery || _lastReachableAt == null;
    _discoveryRunning = true;
    _discoveryFuture = _autoDiscoverServerIfNeeded(deepDiscovery: deepDiscovery);
    try {
      await _discoveryFuture;
    } finally {
      _discoveryRunning = false;
      _discoveryFuture = null;
    }
  }

  bool get _withinDiscoveryCooldown {
    final at = _lastReachableAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _discoveryCooldown;
  }

  void _markReachable() {
    _lastReachableAt = DateTime.now();
  }

  void invalidateReachability() {
    _lastReachableAt = null;
  }

  /// Tries saved URL, then USB (127.0.0.1), emulator, then Wi‑Fi discovery.
  Future<void> _autoDiscoverServerIfNeeded({required bool deepDiscovery}) async {
    final resolved = await resolveReachableApiBase(
      pingHealth: pingHealth,
      savedBase: ApiSettings.current,
      timeout: const Duration(milliseconds: 1200),
      deepDiscovery: deepDiscovery,
    );
    if (resolved == null) return;

    final previous = ApiSettings.current;
    await applyResolvedApiBase(resolved);
    if (resolved != previous) {
      await OfflineCache.clearAll();
    }
    _markReachable();
  }

  Future<void> updateBaseUrl(String input) async {
    await ApiSettings.save(input);
    _settingsLoaded = true;
    invalidateReachability();
    await OfflineCache.clearAll();
  }

  /// Resets saved API host and wipes offline list caches on this phone.
  Future<void> resetSavedConnection() async {
    await ApiSettings.clearSaved();
    _settingsLoaded = true;
    invalidateReachability();
    await OfflineCache.clearAll();
  }

  /// Checks `GET /api/mobile/health` without auth. Returns null on success.
  Future<String?> pingHealth({
    String? baseUrlOverride,
    Duration timeout = _requestTimeout,
  }) async {
    final detail = await pingHealthDetail(
      baseUrlOverride: baseUrlOverride,
      timeout: timeout,
    );
    return detail.error;
  }

  /// Parsed health payload for the Server sheet (null [error] = OK).
  Future<({String? error, Map<String, dynamic>? body})> pingHealthDetail({
    String? baseUrlOverride,
    Duration timeout = _requestTimeout,
  }) async {
    final base = ApiSettings.normalize(baseUrlOverride ?? ApiSettings.current);
    final uri = Uri.parse('$base/health');
    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (
          error: 'Server returned ${response.statusCode} at $base',
          body: null,
        );
      }
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {}

      if (body == null) {
        return (
          error:
              'Wrong service on $base — expected JSON from erp-server (npm start), not Laravel or another app.',
          body: null,
        );
      }

      final apiKind = body['api']?.toString();
      if (apiKind != null && apiKind != 'node-mobile') {
        return (
          error:
              'Wrong API ($apiKind). In erp-server run: npm start\n'
              '(Do not use php artisan serve on port 8000 for the mobile app.)',
          body: body,
        );
      }

      final itemBarcodes = body['itemBarcodes']?.toString();
      if (itemBarcodes == 'missing') {
        return (
          error:
              'MySQL is missing setup_items.barcode. Stop npm start, start WAMP MySQL, then npm start again.',
          body: body,
        );
      }

      if (body['database']?.toString() == 'error') {
        return (error: 'MySQL not reachable from erp-server. Start WAMP first.', body: body);
      }

      if (body['status']?.toString() == 'degraded') {
        return (
          error: 'Server health degraded (database or barcodes). Check npm start console.',
          body: body,
        );
      }

      return (error: null, body: body);
    } catch (error) {
      if (error is ApiException) {
        return (error: error.message, body: null);
      }
      return (error: error.toString(), body: null);
    }
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);
    if (rawUser != null) {
      _user = jsonDecode(rawUser) as Map<String, dynamic>;
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token == null) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return;
    }
    await prefs.setString(_tokenKey, _token!);
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user));
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiSettings.current}$normalized').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = _headers();
    late http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_requestTimeout);
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(_requestTimeout);
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(_requestTimeout);
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_requestTimeout);
        default:
          throw ApiException('Unsupported method $method');
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      invalidateReachability();
      throw ApiException(
        'Network error talking to ${ApiSettings.current}: $error',
      );
    }

    final decoded = await _decode(response);
    _markReachable();
    return decoded;
  }

  Future<dynamic> _decode(http.Response response) async {
    if (response.statusCode == 401) {
      await _expireSession();
      throw ApiException('Session expired. Please sign in again.', statusCode: 401);
    }

    final raw = response.body.isEmpty ? '{}' : response.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw ApiException(
        'Server returned non-JSON response (${response.statusCode}). Check that this endpoint exists on erp-server.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }
  
  Future<Map<String, dynamic>> login(String login, String password) async {
    final payload = await request(
      'POST',
      '/auth/login',
      body: {'login': login, 'password': password},
    ) as Map<String, dynamic>;

    _token = payload['token'] as String?;
    _user = payload['user'] as Map<String, dynamic>?;
    await _persistSession();
    return payload;
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await request('POST', '/auth/logout');
      }
    } catch (_) {
      // Clear local session anyway.
    }
    await clearSession();
  }

  Future<void> _expireSession() async {
    const message = 'Session expired. Please sign in again.';
    await clearSession();
    onSessionExpired?.call(message);
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    await _persistSession();
  }

  Future<Map<String, dynamic>> me() async {
    final payload = await request('GET', '/auth/me') as Map<String, dynamic>;
    _user = payload['user'] as Map<String, dynamic>?;
    await _persistSession();
    return payload;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final payload = await request('GET', path, query: query) as Map<String, dynamic>;
    return (payload['data'] as List<dynamic>? ?? const []);
  }

  Future<Map<String, dynamic>> getOne(String path) async {
    final payload = await request('GET', path) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    final message = payload['message'] is String
        ? payload['message'] as String
        : 'Record not found.';
    throw ApiException(message, statusCode: 404);
  }

  Future<Map<String, dynamic>> getData(
    String path, {
    Map<String, String>? query,
  }) async {
    final payload = await request('GET', path, query: query) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final payload = await request('POST', path, body: body) as Map<String, dynamic>;
    return payload;
  }

  Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) async {
    final payload = await request('PUT', path, body: body) as Map<String, dynamic>;
    return payload;
  }

  Future<Uint8List> getBytes(String path) async {
    final uri = _uri(path);
    final response = await http.get(uri, headers: _headers(json: false));
    if (response.statusCode == 401) {
      await _expireSession();
      throw ApiException('Session expired. Please sign in again.', statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Could not download file.', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadPhotos({
    required String accomplishmentId,
    required List<({String filename, Uint8List bytes})> files,
    int maxAttempts = 3,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final uri = _uri('/accomplishments/$accomplishmentId/photos');
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_headers(json: false));

        for (final file in files) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'photos[]',
              file.bytes,
              filename: file.filename,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        return await _decode(response) as Map<String, dynamic>;
      } on ApiException catch (error) {
        lastError = error;
        // Don't retry auth / validation failures.
        if (error.statusCode == 401 ||
            error.statusCode == 403 ||
            error.statusCode == 422 ||
            attempt == maxAttempts) {
          rethrow;
        }
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) {
          throw ApiException(
            'Network error uploading photos to ${ApiSettings.current}: $error',
          );
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }

    if (lastError is ApiException) {
      throw lastError;
    }
    throw ApiException('Photo upload failed after $maxAttempts attempts.');
  }
}
