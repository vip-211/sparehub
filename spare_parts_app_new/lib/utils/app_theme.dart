import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color secondaryAmber = Color(0xFFFF9800);
  static const Color accentGreen = Color(0xFF00C853);
  
  // Neutral Colors
  static const Color softWhite = Color(0xFFF5F7FA);
  static const Color charcoalBlack = Color(0xFF263238);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  
  // Dashboard Role Colors
  static const Color adminColor = Color(0xFF1E3A8A);
  static const Color mechanicColor = Color(0xFFF59E0B);
  static const Color retailerColor = Color(0xFF10B981);
  static const Color wholesalerColor = Color(0xFF6366F1);
  static const Color staffColor = Color(0xFF14B8A6);

  static const double radiusLg = 24.0;
  static const double radiusMd = 16.0;
  static const double radiusSm = 12.0;

  static TextTheme _textTheme({required bool dark}) {
    final base = (dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(fontFamily: 'Inter');
    final color = dark ? Colors.white : charcoalBlack;
    
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: -1.0),
      displayMedium: base.displayMedium?.copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      displaySmall: base.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w800),
      headlineLarge: base.headlineLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
      headlineMedium: base.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: color.withOpacity(0.9), height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: color.withOpacity(0.8), height: 1.4),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
    );
  }

  static ThemeData lightWithSeed(Color seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: primaryBlue,
      secondary: secondaryAmber,
      tertiary: accentGreen,
      surface: Colors.white,
      background: softWhite,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      typography: Typography.material2021(),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: softWhite,
      fontFamily: 'Inter',
      textTheme: _textTheme(dark: false),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: charcoalBlack,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: charcoalBlack,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: charcoalBlack),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryBlue.withOpacity(0.1),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.w700);
          }
          return TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryBlue);
          }
          return IconThemeData(color: Colors.grey.shade600);
        }),
      ),
    );
  }

  static ThemeData darkWithSeed(Color seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: primaryBlue,
      secondary: secondaryAmber,
      surface: darkSurface,
      background: darkBackground,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      typography: Typography.material2021(),
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Inter',
      textTheme: _textTheme(dark: true),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }

  // Fallbacks
  static ThemeData light() => lightWithSeed(primaryBlue);
  static ThemeData dark() => darkWithSeed(primaryBlue);
  
  // Gradient Utils
  static LinearGradient primaryGradient = const LinearGradient(
    colors: [primaryBlue, Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accentGradient = const LinearGradient(
    colors: [secondaryAmber, Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
