import 'package:flutter/material.dart';

import '../screens/settings_page.dart';

Widget settingsAppBarButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: 'Settings',
    onPressed: () {
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    },
  );
}

Widget backAppBarButton(BuildContext context, {VoidCallback? onPressed}) {
  return IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    tooltip: 'Back',
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

/// Module lists and detail screens: back + optional actions + settings.
PreferredSizeWidget transactionAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? extraActions,
  bool showBack = false,
  VoidCallback? onBack,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    leading: backAppBarButton(context, onPressed: onBack),
    title: Text(
      title,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
    actions: [
      if (extraActions != null) ...extraActions,
      settingsAppBarButton(context),
      const SizedBox(width: 4),
    ],
    bottom: bottom,
  );
}
