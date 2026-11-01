import 'package:flutter/material.dart';

/// Semantic surface/text colors that adapt to light and dark themes.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.heroGradientTop,
    required this.cardShadow,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color heroGradientTop;
  final Color cardShadow;

  static const dark = AppPalette(
    bgPrimary: Color(0xFF0B0B0E),
    bgSecondary: Color(0xFF16161A),
    bgElevated: Color(0xFF1E1E24),
    textPrimary: Color(0xFFF7F7F9),
    textSecondary: Color(0xFFA8A8B3),
    textMuted: Color(0xFF6F6F7A),
    border: Color(0xFF2A2A32),
    divider: Color(0xFF26262E),
    heroGradientTop: Color(0xFF2A1F4D),
    cardShadow: Color(0x40000000),
  );

  static const light = AppPalette(
    bgPrimary: Color(0xFFF6F4F8),
    bgSecondary: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFEEEAF4),
    textPrimary: Color(0xFF18181F),
    textSecondary: Color(0xFF5A5A68),
    textMuted: Color(0xFF8A8A98),
    border: Color(0xFFE2DEE8),
    divider: Color(0xFFE8E4EE),
    heroGradientTop: Color(0xFFE8E0F8),
    cardShadow: Color(0x14000000),
  );

  @override
  AppPalette copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? heroGradientTop,
    Color? cardShadow,
  }) {
    return AppPalette(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgElevated: bgElevated ?? this.bgElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      heroGradientTop: heroGradientTop ?? this.heroGradientTop,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      heroGradientTop: Color.lerp(heroGradientTop, other.heroGradientTop, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}
