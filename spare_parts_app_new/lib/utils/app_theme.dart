import 'package:flutter/material.dart';

class AppTheme {
  static const Color _brandPrimary = Color(0xFF1565C0); // Royal Blue (Replaced Emerald Green)
  static const Color _brandSecondary = Color(0xFF0D47A1); // Darker Blue (Replaced Royal Blue)
  static const Color _surfaceLight = Colors.white;
  static const Color _backgroundLight = Color(0xFFF8F9FA);

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
      primary: _brandPrimary,
      secondary: _brandSecondary,
      surface: _surfaceLight,
      background: _backgroundLight,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      typography: Typography.material2021(),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundLight,
      fontFamily: 'Inter',
      textTheme: _textTheme(dark: false),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1C1E),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A1C1E),
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1C1E)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.grey.shade100, width: 1),
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
          borderSide: const BorderSide(color: _brandPrimary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 8,
          shadowColor: _brandPrimary.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandPrimary,
          side: const BorderSide(color: _brandPrimary, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _brandPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1C1E),
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _brandPrimary.withOpacity(0.08),
        labelStyle:
            const TextStyle(color: _brandPrimary, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 24,
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
