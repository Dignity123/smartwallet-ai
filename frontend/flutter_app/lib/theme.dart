import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legacy dark constants — Prefer `context.palette` in widgets.
class AppColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF111827);
  static const surfaceAlt = Color(0xFF1A2235);
  static const border = Color(0xFF1F2937);
  static const emerald = Color(0xFF00E5A0);
  static const emeraldDim = Color(0x1A00E5A0);
  static const danger = Color(0xFFFF6B6B);
  static const dangerDim = Color(0x1AFF6B6B);
  static const warning = Color(0xFFFFD93D);
  static const warningDim = Color(0x1AFFD93D);
  static const blue = Color(0xFF6BCBFF);
  static const textPrimary = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);
}

class AppColorsLight {
  static const background = Color(0xFFF0F4F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFE8EEF4);
  static const border = Color(0xFFCBD5E1);
  static const emerald = Color(0xFF00A67E);
  static const emeraldDim = Color(0x1A00A67E);
  static const danger = Color(0xFFDC2626);
  static const dangerDim = Color(0x1ADC2626);
  static const warning = Color(0xFFD97706);
  static const warningDim = Color(0x1AD97706);
  static const blue = Color(0xFF0369A1);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);
}

/// Resolved colors for the active theme (use in `build` via `context.palette`).
abstract class AppPalette {
  Color get background;
  Color get surface;
  Color get surfaceAlt;
  Color get border;
  Color get emerald;
  Color get emeraldDim;
  Color get danger;
  Color get dangerDim;
  Color get warning;
  Color get warningDim;
  Color get blue;
  Color get textPrimary;
  Color get textSecondary;
  Color get textMuted;
  /// Text / spinner on solid emerald buttons (high contrast in both modes).
  Color get onEmerald;
}

final class DarkPalette implements AppPalette {
  const DarkPalette();

  @override Color get background => AppColors.background;
  @override Color get surface => AppColors.surface;
  @override Color get surfaceAlt => AppColors.surfaceAlt;
  @override Color get border => AppColors.border;
  @override Color get emerald => AppColors.emerald;
  @override Color get emeraldDim => AppColors.emeraldDim;
  @override Color get danger => AppColors.danger;
  @override Color get dangerDim => AppColors.dangerDim;
  @override Color get warning => AppColors.warning;
  @override Color get warningDim => AppColors.warningDim;
  @override Color get blue => AppColors.blue;
  @override Color get textPrimary => AppColors.textPrimary;
  @override Color get textSecondary => AppColors.textSecondary;
  @override Color get textMuted => AppColors.textMuted;
  @override Color get onEmerald => AppColors.background;
}

final class LightPalette implements AppPalette {
  const LightPalette();

  @override Color get background => AppColorsLight.background;
  @override Color get surface => AppColorsLight.surface;
  @override Color get surfaceAlt => AppColorsLight.surfaceAlt;
  @override Color get border => AppColorsLight.border;
  @override Color get emerald => AppColorsLight.emerald;
  @override Color get emeraldDim => AppColorsLight.emeraldDim;
  @override Color get danger => AppColorsLight.danger;
  @override Color get dangerDim => AppColorsLight.dangerDim;
  @override Color get warning => AppColorsLight.warning;
  @override Color get warningDim => AppColorsLight.warningDim;
  @override Color get blue => AppColorsLight.blue;
  @override Color get textPrimary => AppColorsLight.textPrimary;
  @override Color get textSecondary => AppColorsLight.textSecondary;
  @override Color get textMuted => AppColorsLight.textMuted;
  @override Color get onEmerald => const Color(0xFF04251C);
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).brightness == Brightness.dark ? const DarkPalette() : const LightPalette();
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.emerald,
          error: AppColors.danger,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          iconTheme: const IconThemeData(color: AppColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.emerald,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColorsLight.background,
        colorScheme: const ColorScheme.light(
          surface: AppColorsLight.surface,
          primary: AppColorsLight.emerald,
          error: AppColorsLight.danger,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: AppColorsLight.textPrimary,
          displayColor: AppColorsLight.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColorsLight.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.dmSans(
            color: AppColorsLight.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          iconTheme: const IconThemeData(color: AppColorsLight.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColorsLight.surface,
          selectedItemColor: AppColorsLight.emerald,
          unselectedItemColor: AppColorsLight.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );
}
