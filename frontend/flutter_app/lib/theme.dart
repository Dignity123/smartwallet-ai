import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background   = Color(0xFF0D1117);
  static const surface      = Color(0xFF111827);
  static const surfaceAlt   = Color(0xFF1A2235);
  static const border       = Color(0xFF1F2937);
  static const emerald      = Color(0xFF00E5A0);
  static const emeraldDim   = Color(0x1A00E5A0);
  static const danger       = Color(0xFFFF6B6B);
  static const dangerDim    = Color(0x1AFF6B6B);
  static const warning      = Color(0xFFFFD93D);
  static const warningDim   = Color(0x1AFFD93D);
  static const blue         = Color(0xFF6BCBFF);
  static const textPrimary  = Color(0xFFF9FAFB);
  static const textSecondary= Color(0xFF9CA3AF);
  static const textMuted    = Color(0xFF6B7280);
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
}