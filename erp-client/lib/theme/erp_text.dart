import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Theme-aware text styles — use instead of hardcoded [AppTheme.textPrimary].
class ErpText {
  ErpText._();

  static TextStyle primary(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
  }) {
    return TextStyle(
      color: AppTheme.resolve(context).textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle secondary(
    BuildContext context, {
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
  }) {
    return TextStyle(
      color: AppTheme.resolve(context).textSecondary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle sectionHeader(BuildContext context) {
    return secondary(context, fontSize: 11, fontWeight: FontWeight.w700);
  }
}