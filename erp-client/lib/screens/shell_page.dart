import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/mobile_modules.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../navigation/module_shell.dart';
import '../widgets/brand_logo.dart';
import 'home_page.dart';
import 'settings_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  ApiClient? _api;
  final _homeKey = GlobalKey<HomePageState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<ApiClient>();
  }

  Future<void> _openModule(BuildContext context, MobileModule module) async {
    final api = _api;
    if (api == null) return;

    final onModuleShell = ModalRoute.of(context)?.settings.name == 'module';
    final currentModule = ModalRoute.of(context)?.settings.arguments as MobileModule?;
    final counts = _homeKey.currentState?.moduleCounts ?? const {};

    ModuleShell buildShell() => ModuleShell(
          module: module,
          api: api,
          onOpenModule: _openModule,
          moduleCounts: counts,
        );

    final routeSettings = RouteSettings(name: 'module', arguments: module);

    final openChildFromReceivablesHub =
        onModuleShell &&
        currentModule == MobileModule.receivables &&
        isReceivablesChildModule(module);

    final openChildFromExpensesHub =
        onModuleShell &&
        currentModule == MobileModule.expenses &&
        isExpensesChildModule(module);

    if (openChildFromReceivablesHub || openChildFromExpensesHub) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: routeSettings,
          builder: (routeContext) => buildShell(),
        ),
      );
      return;
    }

    if (onModuleShell) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: routeSettings,
          builder: (routeContext) => buildShell(),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: routeSettings,
        builder: (routeContext) => buildShell(),
      ),
    );

    if (!mounted) return;
    unawaited(_homeKey.currentState?.refreshCounts());
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    unawaited(_homeKey.currentState?.refreshCounts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const BrandLogo(size: 28),
        bottom: PreferredSize(
          preferredSize: Size.zero,
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Settings',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: const Icon(Icons.settings_outlined, size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: HomePage(
        key: _homeKey,
        onOpenModule: (module) => _openModule(context, module),
      ),
    );
  }

}
