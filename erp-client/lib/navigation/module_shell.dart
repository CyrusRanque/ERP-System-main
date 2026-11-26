import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'mobile_modules.dart';
import 'module_navigation_scope.dart';
import '../services/api_client.dart';

class ModuleShell extends StatelessWidget {
  const ModuleShell({
    super.key,
    required this.module,
    required this.api,
    required this.onOpenModule,
    this.moduleCounts = const {},
  });

  final MobileModule module;
  final ApiClient api;
  final void Function(BuildContext context, MobileModule module) onOpenModule;
  final Map<MobileModule, int> moduleCounts;

  @override
  Widget build(BuildContext context) {
    final info = mobileModuleInfo(module);

    return ModuleNavigationScope(
      onOpenModule: onOpenModule,
      child: Scaffold(
        appBar: transactionAppBar(context, title: info.title, showBack: true),
        body: buildMobileModulePage(module, api, counts: moduleCounts),
      ),
    );
  }
}