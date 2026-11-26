import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'erp_colors.dart';

/// Matches office web tokens (`frontend/src/lib/theme.js` + Tailwind `@theme`).
class AppTheme {
  AppTheme._();

  static const maroon = Color(0xFF8B1E3F);
  static const maroonDark = Color(0xFF6F1832);
  static const maroonLight = Color(0xFFF8E9EE);
  static const brandOrange = Color(0xFFF9A61A);
  static const page = Color(0xFFF7F7F8);
  static const textPrimary = Color(0xFF252525);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const successText = Color(0xFF15803D);
  static const warningText = Color(0xFFB45309);
  static const errorText = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEE2E2);

  // Login (matches web mobile login shell).
  static const loginBg = Color(0xFF141018);
  static const loginCard = Color(0xFF1F1619);
  static const loginBorder = Color(0x1AFFFFFF);

  static const logoAsset = 'assets/logo.png';
  static const appDisplayName = 'RTS ERP';

  /// Theme-aware palette — prefer this in widgets over static [textPrimary] / [page].
  static ErpColors resolve(BuildContext context) => ErpColors.of(context);

  static ThemeData light() => _build(Brightness.light, ErpColors.light);

  static ThemeData dark() => _build(Brightness.dark, ErpColors.dark);

  static ThemeData _build(Brightness brightness, ErpColors ext) {
    final isDark = brightness == Brightness.dark;
    final overlayBg = ext.surface;
    final headerFg = ext.textPrimary;
    final accentLink = isDark ? ext.brandAccent : maroon;
    final accentOnTint = isDark ? ext.onBrand : maroon;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: maroon,
      primary: maroon,
      secondary: brandOrange,
      surface: ext.surface,
      onSurface: ext.textPrimary,
      brightness: brightness,
    ).copyWith(
      surfaceTint: Colors.transparent,
      surfaceContainerHighest: overlayBg,
      surfaceContainerHigh: overlayBg,
      surfaceContainer: overlayBg,
      surfaceContainerLow: overlayBg,
      surfaceContainerLowest: overlayBg,
      outline: ext.border,
      onSurface: ext.textPrimary,
      onSurfaceVariant: ext.textSecondary,
    );

    final textTheme = TextTheme(
      displayLarge: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(color: ext.textPrimary, fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(color: ext.textPrimary, fontSize: 14, height: 1.4),
      bodySmall: TextStyle(color: ext.textSecondary, fontSize: 12, height: 1.35),
      labelLarge: TextStyle(color: ext.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: TextStyle(color: ext.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: ext.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
    ).apply(
      bodyColor: ext.textPrimary,
      displayColor: ext.textPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: ext.page,
      fontFamily: 'Segoe UI',
      extensions: [ext],
      brightness: brightness,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      hintColor: ext.textSecondary,
      iconTheme: IconThemeData(color: isDark ? Colors.white : ext.textSecondary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentLink),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: ext.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: overlayBg,
        headerForegroundColor: headerFg,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: overlayBg,
        dayPeriodColor: ext.maroonLight,
        dayPeriodTextColor: maroon,
        dialHandColor: maroon,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: overlayBg,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: overlayBg,
        surfaceTintColor: Colors.transparent,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStatePropertyAll(overlayBg),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: maroonDark,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 0,
        color: ext.surface,
        shadowColor: isDark ? Colors.black54 : Colors.black12,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ext.border, width: isDark ? 1 : 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentLink,
          side: BorderSide(color: ext.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? ext.surfaceMuted : ext.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: maroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorText),
        ),
        labelStyle: TextStyle(color: ext.textSecondary, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: ext.textSecondary),
        floatingLabelStyle: TextStyle(color: isDark ? Colors.white : maroon),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? Colors.white : maroon,
        unselectedLabelColor: ext.textSecondary,
        indicatorColor: maroon,
        dividerColor: ext.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ext.surface,
        indicatorColor: ext.maroonLight,
        elevation: 8,
        shadowColor: Colors.black26,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? (isDark ? Colors.white : maroon) : ext.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? (isDark ? Colors.white : maroon) : ext.textSecondary,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        labelStyle: TextStyle(fontSize: 13, color: ext.textPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ext.surface,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        contentTextStyle: TextStyle(
          color: ext.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? ext.brandAccent : maroon,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: ext.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(color: ext.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(color: ext.textSecondary, fontSize: 13, height: 1.35),
        iconColor: ext.textSecondary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentOnTint;
            return ext.textSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ext.maroonLight;
            return ext.surface;
          }),
          side: WidgetStateProperty.all(BorderSide(color: ext.border)),
        ),
      ),
    );
  }
}