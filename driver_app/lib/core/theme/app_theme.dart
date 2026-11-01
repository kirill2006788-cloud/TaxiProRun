import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Брендовые цвета «КОРОЛИ ДОРОГ» — приложение водителя.
abstract final class AppColors {
  static const Color backgroundPrimary = Color(0xFF0D0D0F);
  static const Color backgroundSecondary = Color(0xFF1A1A1E);
  static const Color backgroundElevated = Color(0xFF242428);

  static const Color lightBackgroundPrimary = Color(0xFFF4F5F8);
  static const Color lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const Color lightBackgroundElevated = Color(0xFFEBEEF5);
  static const Color lightTextPrimary = Color(0xFF1A1F2C);
  static const Color lightTextSecondary = Color(0xFF5A6172);
  static const Color lightTextMuted = Color(0xFF8A93A6);
  static const Color lightBorder = Color(0xFFDDE2EC);
  static const Color lightDivider = Color(0xFFE8ECF3);

  static const Color gold = Color(0xFFF5C518);
  static const Color goldDark = Color(0xFFD4A90F);

  static const Color purple = Color(0xFF7B5CFA);
  static const Color purpleDark = Color(0xFF6344E0);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B8);
  static const Color textMuted = Color(0xFF6E6E76);

  static const Color border = Color(0xFF2E2E34);
  static const Color divider = Color(0xFF2A2A30);

  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

/// Адаптивные поверхности/тексты для light + dark.
@immutable
class AppTokens {
  const AppTokens({
    required this.scaffold,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.isDark,
  });

  final Color scaffold;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final bool isDark;

  static const dark = AppTokens(
    scaffold: AppColors.backgroundPrimary,
    surface: AppColors.backgroundSecondary,
    elevated: AppColors.backgroundElevated,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    divider: AppColors.divider,
    isDark: true,
  );

  static const light = AppTokens(
    scaffold: AppColors.lightBackgroundPrimary,
    surface: AppColors.lightBackgroundSecondary,
    elevated: AppColors.lightBackgroundElevated,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    divider: AppColors.lightDivider,
    isDark: false,
  );

  static AppTokens of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  Color get onGold =>
      isDark ? AppColors.backgroundPrimary : AppColors.lightTextPrimary;
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
}

abstract final class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary, Color muted) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: primary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
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
    );
  }

  static ThemeData get dark {
    const tokens = AppTokens.dark;
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.purple,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.gold,
      onSecondary: AppColors.backgroundPrimary,
      surface: AppColors.backgroundSecondary,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
      outline: AppColors.border,
    );

    return _build(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      tokens: tokens,
      statusIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      selectedNav: AppColors.gold,
      goldButtonFg: AppColors.backgroundPrimary,
    );
  }

  static ThemeData get light {
    const tokens = AppTokens.light;
    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: AppColors.purple,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.goldDark,
      onSecondary: AppColors.lightTextPrimary,
      surface: AppColors.lightBackgroundSecondary,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
      outline: AppColors.lightBorder,
    );

    return _build(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      tokens: tokens,
      statusIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      selectedNav: AppColors.goldDark,
      goldButtonFg: AppColors.lightTextPrimary,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required AppTokens tokens,
    required Brightness statusIconBrightness,
    required Brightness statusBarBrightness,
    required Color selectedNav,
    required Color goldButtonFg,
  }) {
    final textTheme = _textTheme(
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.scaffold,
      canvasColor: tokens.scaffold,
      dividerColor: tokens.divider,
      splashColor: AppColors.purple.withValues(alpha: 0.12),
      highlightColor: AppColors.purple.withValues(alpha: 0.08),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: tokens.scaffold,
        foregroundColor: tokens.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIconBrightness,
          statusBarBrightness: statusBarBrightness,
        ),
        titleTextStyle: GoogleFonts.manrope(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: tokens.border.withValues(
              alpha: brightness == Brightness.dark ? 0.55 : 0.85,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: tokens.textMuted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: tokens.border.withValues(
              alpha: brightness == Brightness.dark ? 0.55 : 0.9,
            ),
          ),
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
          foregroundColor: goldButtonFg,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
          disabledForegroundColor: goldButtonFg.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(
            color: tokens.border.withValues(
              alpha: brightness == Brightness.dark ? 0.55 : 0.9,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purple,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return tokens.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.purple;
          }
          return tokens.elevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.elevated,
        selectedColor: AppColors.purple.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: tokens.border.withValues(
            alpha: brightness == Brightness.dark ? 0.55 : 0.9,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: selectedNav,
        unselectedItemColor: tokens.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        tileColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.elevated,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.manrope(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.manrope(
          color: tokens.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: tokens.textMuted.withValues(alpha: 0.45),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.purple,
      ),
      iconTheme: IconThemeData(
        color: tokens.textSecondary,
        size: 24,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: tokens.surface,
        headerBackgroundColor: AppColors.purple.withValues(alpha: 0.15),
      ),
    );
  }
}
