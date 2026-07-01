import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color darkBg = Color(0xFF0C1017);
  static const Color darkSurface = Color(0xFF161E2E);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonOrange = Color(0xFFFF5722);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonYellow = Color(0xFFFFD600);
  
  static const double cardRadiusVal = 20.0;
  static final BorderRadius cardRadius = BorderRadius.circular(cardRadiusVal);
  static final Border glassBorder = Border.all(color: Colors.white.withOpacity(0.04));
  static final BoxDecoration glassDecoration = BoxDecoration(
    color: darkSurface,
    borderRadius: cardRadius,
    border: glassBorder,
  );
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0091EA),
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(color: Color(0xFF64748B)),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        primary: neonCyan,
        secondary: neonOrange,
        tertiary: neonGreen,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}