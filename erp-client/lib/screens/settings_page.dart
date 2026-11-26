import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../state/theme_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/expenses_module_list.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Color _settingsIconTint(bool isDark, Color lightTint) =>
      isDark ? AppTheme.brandOrange : lightTint;

  static Color _settingsIconBg(bool isDark, Color lightBg) =>
      isDark ? const Color(0xFF3D3018) : lightBg;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final themePrefs = context.watch<ThemePreferences>();
    final name = auth.user?['name']?.toString().trim();
    final login = auth.user?['login']?.toString().trim();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = AppTheme.resolve(context);

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        children: [
          const ExpensesSectionLabel('General'),
          const SizedBox(height: 8),
          if (name != null && name.isNotEmpty)
            _SettingsCard(
              child: _SettingsOptionTile(
                icon: Icons.person_outline_rounded,
                iconTint: _settingsIconTint(isDark, const Color(0xFF2563EB)),
                iconBg: _settingsIconBg(isDark, const Color(0xFFEFF6FF)),
                title: name,
                subtitle: login?.isNotEmpty == true ? login! : 'Signed-in account',
                showChevron: false,
              ),
            ),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _settingsIconBg(isDark, colors.maroonLight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.palette_outlined,
                          color: _settingsIconTint(isDark, AppTheme.maroon),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Appearance',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined, size: 18),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined, size: 18),
                          label: Text('Auto'),
                        ),
                      ],
                      selected: {themePrefs.mode},
                      onSelectionChanged: themePrefs.loaded
                          ? (selection) => themePrefs.setMode(selection.first)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    themePrefs.mode == ThemeMode.system
                        ? 'Matches your phone light/dark setting'
                        : '${themePrefs.modeLabel} mode',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.busy ? null : () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorText,
                    side: BorderSide(color: colors.border),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: auth.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    auth.busy ? 'Signing out…' : 'Sign out',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: child,
    );
  }
}

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.icon,
    required this.iconTint,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconTint;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.resolve(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconTint, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron && onTap != null)
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}