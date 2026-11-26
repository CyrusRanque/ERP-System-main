import 'package:flutter/material.dart';

import '../navigation/mobile_modules.dart';
import '../theme/app_theme.dart';

class ModuleIconTile extends StatelessWidget {
  const ModuleIconTile({
    super.key,
    required this.module,
    required this.count,
    required this.onTap,
    this.iconBoxSize = 60,
  });

  final MobileModuleInfo module;
  final int count;
  final VoidCallback onTap;
  final double iconBoxSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.resolve(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = iconBoxSize * 0.3;
    final iconSize = iconBoxSize * 0.48;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: colors.brandSurface,
                  borderRadius: BorderRadius.circular(radius),
                  border: isDark
                      ? Border.all(
                          color: AppTheme.brandOrange.withValues(alpha: 0.35),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(module.icon, color: colors.onBrand, size: iconSize),
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.brandOrange : AppTheme.maroon,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      border: isDark
                          ? Border.all(color: colors.surface, width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            module.gridLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: iconBoxSize >= 60 ? 12 : 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleIconGrid extends StatelessWidget {
  const ModuleIconGrid({
    super.key,
    required this.modules,
    required this.countFor,
    required this.onOpen,
  });

  final List<MobileModuleInfo> modules;
  final int Function(MobileModule id) countFor;
  final ValueChanged<MobileModule> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const mainAxisSpacing = 20.0;
        const crossAxisSpacing = 4.0;
        final cellWidth =
            (constraints.maxWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
        final iconBox = (cellWidth * 0.62).clamp(52.0, 64.0);
        const labelBlock = 30.0;
        const iconLabelGap = 8.0;
        final cellHeight = iconBox + iconLabelGap + labelBlock;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return ModuleIconTile(
              module: module,
              count: countFor(module.id),
              iconBoxSize: iconBox,
              onTap: () => onOpen(module.id),
            );
          },
        );
      },
    );
  }
}