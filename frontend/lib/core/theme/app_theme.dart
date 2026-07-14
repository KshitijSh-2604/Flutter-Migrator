import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF0553B1);   // Flutter blue
  static const _secondaryColor = Color(0xFF54C5F8);
  static const _surfaceDark = Color(0xFF1E2130);
  static const _bgDark = Color(0xFF141824);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.outfitTextTheme(),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
      surface: _surfaceDark,
      background: _bgDark,
    ),
    scaffoldBackgroundColor: _bgDark,
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: _bgDark,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: _surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}