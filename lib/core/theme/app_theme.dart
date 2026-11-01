import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// Brand accents + theme-adaptive surfaces.
///
/// Surface/text getters follow the active [AppPalette] bound from [MaterialApp]
/// via [AppColors.applyPalette]. Prefer [BuildContext.palette] in new code.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.dark;

  static void applyPalette(AppPalette palette) => _palette = palette;

  static AppPalette get palette => _palette;

  // —— Brand (fixed) ——
  static const Color gold = Color(0xFFF5C518);
  static const Color goldDark = Color(0xFFD4A90F);
  static const Color purple = Color(0xFF7B5CFA);
  static const Color purpleDark = Color(0xFF6344E0);
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFEF4444);

  // —— Adaptive surfaces / text ——
  static Color get backgroundPrimary => _palette.bgPrimary;
  static Color get backgroundSecondary => _palette.bgSecondary;
  static Color get backgroundElevated => _palette.bgElevated;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get border => _palette.border;
  static Color get divider => _palette.divider;

  // —— Explicit light tokens (legacy / docs) ——
  static const Color lightBackgroundPrimary = Color(0xFFF6F4F8);
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightBackgroundElevated = Color(0xFFEEEAF4);
  static const Color lightTextPrimary = Color(0xFF18181F);
  static const Color lightTextSecondary = Color(0xFF5A5A68);
  static const Color lightTextMuted = Color(0xFF8A8A98);
  static const Color lightBorder = Color(0xFFE2DEE8);
}

abstract final class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary, Color muted) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: primary,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: primary,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: primary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: primary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: secondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: secondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: AppColors.purple,
          onPrimary: Color(0xFFFFFFFF),
          secondary: AppColors.gold,
          onSecondary: Color(0xFF0B0B0E),
          surface: Color(0xFF16161A),
          onSurface: Color(0xFFF7F7F9),
          error: AppColors.error,
          onError: Color(0xFFFFFFFF),
          outline: Color(0xFF2A2A32),
        ),
        statusIcons: Brightness.light,
        statusBrightness: Brightness.dark,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        palette: AppPalette.light,
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: AppColors.purple,
          onPrimary: Color(0xFFFFFFFF),
          secondary: AppColors.goldDark,
          onSecondary: Color(0xFF18181F),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF18181F),
          error: AppColors.error,
          onError: Color(0xFFFFFFFF),
          outline: Color(0xFFE2DEE8),
        ),
        statusIcons: Brightness.dark,
        statusBrightness: Brightness.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required ColorScheme colorScheme,
    required Brightness statusIcons,
    required Brightness statusBrightness,
  }) {
    final textTheme = _textTheme(
      palette.textPrimary,
      palette.textSecondary,
      palette.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.bgPrimary,
      canvasColor: palette.bgPrimary,
      dividerColor: palette.divider,
      splashColor: AppColors.purple.withValues(alpha: 0.1),
      highlightColor: AppColors.purple.withValues(alpha: 0.06),
      extensions: [palette],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: palette.bgPrimary,
        foregroundColor: palette.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIcons,
          statusBarBrightness: statusBrightness,
        ),
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.bgSecondary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: palette.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: palette.border.withValues(
              alpha: brightness == Brightness.dark ? 0.55 : 0.85,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.bgElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w500),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF0B0B0E),
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
          disabledForegroundColor: const Color(0xFF0B0B0E).withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.purple.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purple,
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.purple;
          return palette.bgElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.purple;
          return palette.textMuted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.purple;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: palette.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.bgElevated,
        selectedColor: AppColors.purple.withValues(alpha: 0.16),
        disabledColor: palette.bgElevated,
        labelStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: palette.textSecondary),
        side: BorderSide(
          color: palette.border.withValues(
            alpha: brightness == Brightness.dark ? 0.55 : 0.9,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.bgSecondary,
        modalBackgroundColor: palette.bgSecondary,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: palette.textMuted.withValues(alpha: 0.45),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.bgElevated,
        contentTextStyle: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.purple,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.bgSecondary,
        indicatorColor: AppColors.purple.withValues(
          alpha: brightness == Brightness.dark ? 0.22 : 0.14,
        ),
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (brightness == Brightness.dark ? AppColors.gold : AppColors.goldDark)
                : palette.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? (brightness == Brightness.dark ? AppColors.gold : AppColors.goldDark)
                : palette.textMuted,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1, space: 1),
    );
  }

  static ButtonStyle get goldButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF0B0B0E),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
      );

  static ButtonStyle get purpleButton => FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
      );

  static BoxDecoration tariffCardDecoration(
    BuildContext context, {
    required bool isSelected,
  }) {
    final p = context.palette;
    return BoxDecoration(
      color: p.bgSecondary,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isSelected ? AppColors.gold : p.border,
        width: isSelected ? 2 : 1,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration softCard(BuildContext context, {bool elevated = false}) {
    final p = context.palette;
    final dark = context.isDarkTheme;
    return BoxDecoration(
      color: elevated ? p.bgElevated : p.bgSecondary,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: p.border.withValues(alpha: dark ? 0.5 : 0.8),
      ),
      boxShadow: [
        BoxShadow(
          color: p.cardShadow,
          blurRadius: elevated ? 22 : 14,
          offset: Offset(0, elevated ? 8 : 5),
        ),
      ],
    );
  }

  static LinearGradient heroGradient(BuildContext context) {
    final p = context.palette;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(p.heroGradientTop, AppColors.purple, 0.35)!
            .withValues(alpha: context.isDarkTheme ? 0.55 : 0.9),
        p.bgPrimary.withValues(alpha: 0.94),
        p.bgPrimary,
      ],
      stops: const [0.0, 0.42, 1.0],
    );
  }
}
