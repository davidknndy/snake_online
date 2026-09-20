import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SnakeTheme {
  // Classic Snake game colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color background = Color(0xFF1B5E20);
  static const Color gameBackground = Color(0xFF2E7D32);
  static const Color snakeColor = Color(0xFF4CAF50);
  static const Color foodColor = Color(0xFFF44336);
  static const Color wallColor = Color(0xFF795548);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE8F5E8);
  static const Color cardBackground = Color(0xFF388E3C);
  static const Color buttonColor = Color(0xFF66BB6A);
  static const Color buttonDisabled = Color(0xFF757575);
  static const Color accentColor = Color(0xFFFFEB3B);

  static String? get fontFamily => GoogleFonts.rajdhani().fontFamily;

  static TextStyle getFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get theme {
    final baseTextTheme = GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      primarySwatch: Colors.green,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: darkGreen,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: lightGreen, width: 2),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          side: const BorderSide(color: lightGreen, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightGreen, width: 1),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.rajdhani(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.rajdhani(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.rajdhani(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.rajdhani(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.rajdhani(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.rajdhani(
          color: textSecondary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.rajdhani(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.dark,
        primary: primaryGreen,
        secondary: accentColor,
        surface: cardBackground,
        onPrimary: textPrimary,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
    );
  }

  // Custom button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: buttonColor,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: lightGreen, width: 2),
    ),
    elevation: 8,
    shadowColor: darkGreen,
    textStyle: GoogleFonts.rajdhani(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: textPrimary,
    backgroundColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    side: const BorderSide(color: lightGreen, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: GoogleFonts.rajdhani(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
    ),
  );

  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
}
