import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF6B5B95);
  static const Color accentColor = Color(0xFF82B366);
  static const Color secondaryColor = Color(0xFF88B0D3);
  
  // Background Colors
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textTertiary = Color(0xFF9AA0A6);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB8BCC0);
  static const Color darkTextTertiary = Color(0xFF80868B);
  
  // Semantic Colors
  static const Color successColor = Color(0xFF34A853);
  static const Color warningColor = Color(0xFFFBBC04);
  static const Color errorColor = Color(0xFFEA4335);
  static const Color infoColor = Color(0xFF4285F4);
  
  // Additional Colors
  static const Color dividerColor = Color(0xFFE8EAED);
  static const Color darkDividerColor = Color(0xFF3C4043);
  
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusRound = 30.0;
  
  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Elevation
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationLarge = 4.0;
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Animation Curves
  static const Curve animationCurve = Curves.easeInOut;
  static const Curve animationCurveSmooth = Curves.easeInOutCubic;
  static const Curve animationCurveBounce = Curves.elasticOut;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
        displaySmall: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary),
      ),
      cardTheme: CardThemeData(
        elevation: elevationMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        color: surfaceColor,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationSmall,
          shadowColor: primaryColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: spacingLarge, vertical: spacingMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: spacingMedium, vertical: spacingSmall),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: spacingLarge, vertical: spacingMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: elevationLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMedium, vertical: spacingMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: textSecondary),
        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: textTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        backgroundColor: darkSurfaceColor,
        contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: secondaryColor,
        surface: darkSurfaceColor,
        background: darkBackgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
        onBackground: darkTextPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w700, color: darkTextPrimary),
        displayMedium: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w600, color: darkTextPrimary),
        displaySmall: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w600, color: darkTextPrimary),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, color: darkTextPrimary),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        headlineSmall: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleSmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, color: darkTextSecondary),
        labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
        labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: darkTextPrimary),
        labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        elevation: elevationSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        color: darkSurfaceColor,
        shadowColor: Colors.black.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: elevationSmall,
          shadowColor: primaryColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: spacingLarge, vertical: spacingMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: spacingMedium, vertical: spacingSmall),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: spacingLarge, vertical: spacingMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: elevationLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMedium, vertical: spacingMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: darkTextSecondary),
        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: darkTextTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDividerColor,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        backgroundColor: const Color(0xFF2A2A2A),
        contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white),
      ),
    );
  }

  static ThemeData get theme => lightTheme;
}
