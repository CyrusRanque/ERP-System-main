import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_settings.dart';

typedef HealthPing = Future<String?> Function({
  String? baseUrlOverride,
  Duration timeout,
});

/// Finds erp-server on the same /24 as this phone (when UDP discovery is blocked).
Future<String?> scanLanForMobileApi({
  required HealthPing pingHealth,
  int port = ApiSettings.defaultPort,
  Duration hostTimeout = const Duration(milliseconds: 700),
}) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return null;
  }

  final prefix = await _phoneSubnetPrefix();
  if (prefix == null) return null;

  final order = _hostScanOrder(prefix);
  const batchSize = 32;

  for (var start = 0; start < order.length; start += batchSize) {
    final end = (start + batchSize > order.length) ? order.length : start + batchSize;
    final batch = order.sublist(start, end);
    final found = await _scanBatch(
      prefix: prefix,
      hosts: batch,
      port: port,
      hostTimeout: hostTimeout,
      pingHealth: pingHealth,
    );
    if (found != null) return found;
  }
  return null;
}

Future<String?> _scanBatch({
  required String prefix,
  required List<int> hosts,
  required int port,
  required Duration hostTimeout,
  required HealthPing pingHealth,
}) async {
  final completer = Completer<String?>();
  var pending = hosts.length;

  for (final host in hosts) {
    unawaited(() async {
      final base = 'http://$prefix$host:$port/api/mobile';
      try {
        final err = await pingHealth(baseUrlOverride: base, timeout: hostTimeout);
        if (err == null && !completer.isCompleted) {
          completer.complete(base);
        }
      } finally {
        pending -= 1;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }());
  }

  return completer.future;
}

Future<String?> _phoneSubnetPrefix() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        final parts = ip.split('.');
        if (parts.length != 4) continue;
        final a = int.tryParse(parts[0]);
        final b = int.tryParse(parts[1]);
        if (a == null || b == null) continue;
        final isPrivate = a == 10 ||
            (a == 172 && b >= 16 && b <= 31) ||
            (a == 192 && b == 168);
        if (!isPrivate) continue;
        return '${parts[0]}.${parts[1]}.${parts[2]}.';
      }
    }
  } catch (_) {}
  return null;
}

List<int> _hostScanOrder(String prefix) {
  final seen = <int>{};
  final order = <int>[];

  void add(int host) {
    if (host < 1 || host > 254) return;
    if (seen.add(host)) order.add(host);
  }

  final saved = ApiSettings.savedHostPort;
  final savedHost = saved.split(':').first;
  if (savedHost.startsWith(prefix)) {
    final last = int.tryParse(savedHost.split('.').last);
    if (last != null) add(last);
  }

  for (final n in [1, 2, 10, 20, 50, 60, 100, 105, 254]) {
    add(n);
  }
  for (var i = 1; i <= 254; i++) {
    add(i);
  }
  return order;
}
