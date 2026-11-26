import 'package:flutter/material.dart';

/// Semantic colors that follow light / dark mode (via [ThemeExtension]).
@immutable
class ErpColors extends ThemeExtension<ErpColors> {
  const ErpColors({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.maroonLight,
    required this.errorBg,
    required this.warningBg,
    required this.successBg,
    required this.brandSurface,
    required this.onBrand,
    required this.brandAccent,
  });

  final Color page;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color maroonLight;
  final Color errorBg;
  final Color warningBg;
  final Color successBg;

  /// Background behind module / hub icons (pink tile in light, maroon in dark).
  final Color brandSurface;

  /// Icon color on [brandSurface] (maroon in light, white in dark).
  final Color onBrand;

  /// Secondary brand text (e.g. counts, links) tuned per mode.
  final Color brandAccent;

  static const light = ErpColors(
    page: Color(0xFFF7F7F8),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF7F7F8),
    textPrimary: Color(0xFF252525),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    maroonLight: Color(0xFFF8E9EE),
    errorBg: Color(0xFFFEE2E2),
    warningBg: Color(0xFFFEF3C7),
    successBg: Color(0xFFDCFCE7),
    brandSurface: Color(0xFFF8E9EE),
    onBrand: Color(0xFF8B1E3F),
    brandAccent: Color(0xFF8B1E3F),
  );

  /// Warm charcoal + maroon — aligned with login shell and app bar.
  static const dark = ErpColors(
    page: Color(0xFF141018),
    surface: Color(0xFF1F1D24),
    surfaceMuted: Color(0xFF2A2830),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE4E1E8),
    border: Color(0xFF3A3742),
    maroonLight: Color(0xFF3A2230),
    errorBg: Color(0xFF3D1818),
    warningBg: Color(0xFF3D3218),
    successBg: Color(0xFF163422),
    // Module tiles: warm brown field + logo-yellow glyphs.
    brandSurface: Color(0xFF3D2A1C),
    onBrand: Color(0xFFF9A61A),
    brandAccent: Color(0xFFFFB84D),
  );

  static ErpColors of(BuildContext context) {
    return Theme.of(context).extension<ErpColors>() ?? light;
  }

  @override
  ErpColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? maroonLight,
    Color? errorBg,
    Color? warningBg,
    Color? successBg,
    Color? brandSurface,
    Color? onBrand,
    Color? brandAccent,
  }) {
    return ErpColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      maroonLight: maroonLight ?? this.maroonLight,
      errorBg: errorBg ?? this.errorBg,
      warningBg: warningBg ?? this.warningBg,
      successBg: successBg ?? this.successBg,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrand: onBrand ?? this.onBrand,
      brandAccent: brandAccent ?? this.brandAccent,
    );
  }

  @override
  ErpColors lerp(ThemeExtension<ErpColors>? other, double t) {
    if (other is! ErpColors) return this;
    return ErpColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      maroonLight: Color.lerp(maroonLight, other.maroonLight, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
    );
  }
}