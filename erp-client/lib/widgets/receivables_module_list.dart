import 'package:flutter/material.dart';

import '../navigation/mobile_modules.dart';
import '../theme/app_theme.dart';

class ReceivablesModuleListTile extends StatelessWidget {
  const ReceivablesModuleListTile({
    super.key,
    required this.info,
    required this.onTap,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  final MobileModuleInfo info;
  final VoidCallback onTap;
  final bool showBadge;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.resolve(context);
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.brandSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: colors.onBrand, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.effectiveNavLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (showBadge && badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceivablesSectionLabel extends StatelessWidget {
  const ReceivablesSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.maroon,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped receivables items for mobile list navigation.
const receivablesPostingModules = <MobileModule>[
  MobileModule.arEntry,
  MobileModule.billing,
];

const receivablesReportModules = <MobileModule>[
  MobileModule.receivablesSoa,
  MobileModule.customerLedger,
  MobileModule.arAging,
];