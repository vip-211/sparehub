import 'package:flutter/material.dart';

class AppTheme {
  static const Color _brandPrimary = Color.fromARGB(255, 10, 194, 226); // Royal Blue (Replaced Emerald Green)
  static const Color _brandSecondary = Color.fromARGB(255, 231, 8, 64); // Darker Blue (Replaced Royal Blue)
  
  // Dynamic Dashboard Colors
  static const Color adminColor = Color(0xFF1E3A8A);      // Deep Blue
  static const Color mechanicColor = Color(0xFFF59E0B);   // Amber/Orange
  static const Color retailerColor = Color(0xFF10B981);   // Emerald Green
  static const Color wholesalerColor = Color(0xFF6366F1); // Indigo
  static const Color staffColor = Color(0xFF14B8A6);      // Teal
  
  static const Color _surfaceLight = Colors.white;
  static const Color _backgroundLight = Colors.white; // Changed from Color(0xFFF8F9FA) to Colors.white

  static const double radiusLg = 24;
  static const double radiusMd = 18;

  static TextTheme _textTheme({required bool dark}) {
    final base = (dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(fontFamily: 'Inter');
    final on = dark ? Colors.white : const Color(0xFF1A1C1E);
    return base.copyWith(
      displaySmall:
          base.displaySmall?.copyWith(color: on, fontWeight: FontWeight.w800),
      headlineSmall:
          base.headlineSmall?.copyWith(color: on, fontWeight: FontWeight.w800),
      titleLarge:
          base.titleLarge?.copyWith(color: on, fontWeight: FontWeight.w800),
      bodyLarge: base.bodyLarge?.copyWith(color: on.withOpacity(0.9)),
      bodyMedium: base.bodyMedium?.copyWith(color: on.withOpacity(0.8)),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData lightWithSeed(Color seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
      surface: _surfaceLight,
      background: _backgroundLight,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      typography: Typography.material2021(),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      dialogBackgroundColor: Colors.white,
      fontFamily: 'Inter',
      textTheme: _textTheme(dark: false),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: seed,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Disable Material 3 surface tinting
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        surfaceTintColor: Colors.transparent, // Disable Material 3 surface tinting
        indicatorColor: seed.withOpacity(0.1),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: seed);
          }
          return IconThemeData(color: Colors.grey.shade600);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(
                color: seed, fontSize: 12, fontWeight: FontWeight.w800);
          }
          return TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: seed.withOpacity(0.1),
        color: _surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: seed.withOpacity(0.05), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: seed, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shadowColor: seed.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          backgroundColor: seed,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
    );
  }

  static ThemeData darkWithSeed(Color seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: _brandPrimary,
      secondary: _brandSecondary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      typography: Typography.material2021(),
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      textTheme: _textTheme(dark: true),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // Backwards-compatible fallbacks
  static ThemeData light() => lightWithSeed(_brandPrimary);
  static ThemeData dark() => darkWithSeed(_brandPrimary);
}
