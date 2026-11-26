import 'package:flutter/material.dart';

import '../navigation/mobile_modules.dart';
import '../navigation/module_navigation_scope.dart';
import '../theme/app_theme.dart';
import '../theme/erp_text.dart';
import '../widgets/expenses_module_list.dart';

class ExpensesHubPage extends StatelessWidget {
  const ExpensesHubPage({
    super.key,
    required this.counts,
  });

  final Map<MobileModule, int> counts;

  int get _openPayables => counts[MobileModule.expenses] ?? 0;

  MobileModuleInfo _info(MobileModule id) => mobileModuleInfo(id);

  @override
  Widget build(BuildContext context) {
    final scope = ModuleNavigationScope.maybeOf(context);
    final onOpen = scope?.onOpenModule;

    void open(MobileModule module) {
      if (onOpen == null) return;
      onOpen(context, module);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_openPayables > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.maroon, AppTheme.maroonDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart_checkout_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_openPayables open PO${_openPayables == 1 ? '' : 's'} in payables',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    'Petty cash, AP posting, disbursements, and supplier reports.',
                    style: ErpText.secondary(context, fontSize: 13, height: 1.4),
                  ),
                ),
                const ExpensesSectionLabel('POSTING'),
                ...expensesPostingModules.map((id) {
                  return ExpensesModuleListTile(
                    info: _info(id),
                    onTap: () => open(id),
                  );
                }),
                const Divider(height: 1),
                const ExpensesSectionLabel('REPORTS'),
                ...expensesReportModules.map((id) {
                  return ExpensesModuleListTile(
                    info: _info(id),
                    onTap: () => open(id),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}