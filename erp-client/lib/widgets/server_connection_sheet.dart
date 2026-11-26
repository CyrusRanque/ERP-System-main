import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/api_discovery.dart';
import '../services/api_settings.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../theme/erp_text.dart';

/// Change API server (LAN IP) without rebuilding the APK.
Future<void> showServerConnectionSheet(BuildContext context) async {
  final rootContext = context;
  final api = rootContext.read<ApiClient>();
  await showModalBottomSheet<void>(
    context: rootContext,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _ServerConnectionSheetBody(
        sheetContext: sheetContext,
        rootContext: rootContext,
        api: api,
      );
    },
  );
}

class _ServerConnectionSheetBody extends StatefulWidget {
  const _ServerConnectionSheetBody({
    required this.sheetContext,
    required this.rootContext,
    required this.api,
  });

  final BuildContext sheetContext;
  final BuildContext rootContext;
  final ApiClient api;

  @override
  State<_ServerConnectionSheetBody> createState() => _ServerConnectionSheetBodyState();
}

class _ServerConnectionSheetBodyState extends State<_ServerConnectionSheetBody> {
  late final TextEditingController _controller;
  late final bool _usesEmulatorHost;
  final _serverFieldKey = GlobalKey();

  bool _testing = false;
  bool _scanning = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final current = ApiSettings.current;
    _usesEmulatorHost = current.contains('10.0.2.2');
    _controller = TextEditingController(
      text: _usesEmulatorHost
          ? '192.168.1.60:8000'
          : ApiSettings.displayHostPort(current),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAfterSheetClosed(Future<void> Function() action) {
    final root = widget.rootContext;
    final messenger = ScaffoldMessenger.maybeOf(root);

    Navigator.of(widget.sheetContext).pop();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>(() async {
        await Future<void>.delayed(Duration.zero);
        if (!root.mounted) return;
        await action();
        if (!root.mounted) return;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Connected to ${ApiSettings.savedHostPort} — offline cache cleared. Pull down to refresh lists.',
            ),
          ),
        );
      });
    });
  }

  Future<void> _saveAndConnect() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _testOk = false;
        _testResult = 'Enter your PC IP, e.g. 192.168.1.60:8000';
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _testOk = false;
    });
    final detail = await widget.api.pingHealthDetail(baseUrlOverride: raw);
    if (!mounted) return;
    if (detail.error != null) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult =
            '${detail.error}\nCheck: WAMP MySQL on, npm start in erp-server, phone on same Wi‑Fi, Windows Firewall allows port 8000.';
      });
      return;
    }
    await widget.api.updateBaseUrl(raw);
    if (!mounted) return;
    setState(() => _testing = false);
    final root = widget.rootContext;
    _scheduleAfterSheetClosed(() => root.read<AuthState>().refreshAfterServerChange());
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + safeBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            'API server',
            style: Theme.of(widget.sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maroon,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _usesEmulatorHost
                ? 'On a real phone the app finds your PC on the same Wi‑Fi automatically when you open the app or tap Find server. You can also type host:port, e.g. 192.168.1.60:8000'
                : 'Server address is saved as host:port. If your PC IP changes, pull to refresh or tap Find server on Wi‑Fi.',
            style: ErpText.secondary(context, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            key: _serverFieldKey,
            controller: _controller,
            textInputAction: TextInputAction.done,
            scrollPadding: const EdgeInsets.only(bottom: 160),
            decoration: const InputDecoration(
              labelText: 'Server (host:port)',
              hintText: '192.168.1.60:8000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onTap: () {
              Future<void>.delayed(const Duration(milliseconds: 280), () {
                final fieldContext = _serverFieldKey.currentContext;
                if (fieldContext == null || !mounted) return;
                Scrollable.ensureVisible(
                  fieldContext,
                  alignment: 0.35,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_testing || _scanning)
                ? null
                : () async {
                    setState(() {
                      _scanning = true;
                      _testResult = null;
                      _testOk = false;
                    });
                    var found = await ApiDiscovery.discover();
                    if (found != null) {
                      _controller.text = ApiSettings.savedHostPortFrom(found);
                    } else if (mounted) {
                      await widget.api.ensureConfigured(forceDiscovery: true);
                      if (ApiSettings.savedHostPort.isNotEmpty) {
                        _controller.text = ApiSettings.savedHostPort;
                        found = ApiSettings.current;
                      }
                    }
                    if (!mounted) return;
                    setState(() {
                      _scanning = false;
                      _testOk = found != null;
                      _testResult = found != null
                          ? 'Found server at ${ApiSettings.savedHostPortFrom(found!)}'
                          : 'No server on this Wi‑Fi. Is npm start running on your PC?';
                    });
                  },
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find_outlined, size: 18),
            label: Text(_scanning ? 'Searching…' : 'Find server on Wi‑Fi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testing
                ? null
                : () async {
                    setState(() {
                      _testing = true;
                      _testResult = null;
                      _testOk = false;
                    });
                    final detail =
                        await widget.api.pingHealthDetail(baseUrlOverride: _controller.text);
                    if (!mounted) return;
                    setState(() {
                      _testing = false;
                      _testOk = detail.error == null;
                      if (detail.error != null) {
                        _testResult = detail.error;
                      } else {
                        final b = detail.body;
                        _testResult =
                            'Connected — ${b?['api'] ?? 'mobile'} API, item barcodes ${b?['itemBarcodes'] ?? 'ok'}';
                      }
                    });
                  },
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_outlined, size: 18),
            label: Text(_testing ? 'Testing…' : 'Test connection'),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(
                fontSize: 12,
                color: _testOk ? AppTheme.successText : AppTheme.errorText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await widget.api.resetSavedConnection();
              _controller.text = _usesEmulatorHost
                  ? ''
                  : ApiSettings.displayHostPort(ApiSettings.builtinDefault);
              setState(() {
                _testResult = 'Server and offline lists reset to default.';
                _testOk = true;
              });
            },
            child: const Text('Reset saved server & clear offline lists'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _testing ? null : _saveAndConnect,
            child: const Text('Save & connect'),
          ),
          ],
        ),
      ),
    );
  }
}