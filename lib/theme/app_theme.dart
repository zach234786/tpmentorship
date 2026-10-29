import 'package:flutter/material.dart';

class AppPalette {
// one complete colour scheme for the app
// (part 3 personalisation: the user can switch between palettes)
  final String name;
  final bool isDark;
  final Color accent;
  final Color accentLight;
  final Color bg;
  final Color cardBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppPalette({
    required this.name,
    required this.isDark,
    required this.accent,
    required this.accentLight,
    required this.bg,
    required this.cardBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class AppTheme {
// holds the colours every screen uses (eg AppTheme.tpRed) and builds
// the MaterialApp ThemeData from them
//
// the colour fields are not const anymore - applyPalette() swaps their
// values when the user picks a different theme in settings, then the
// whole app rebuilds so every screen picks up the new colours

  // ----- the three palettes the user can pick from -----
  // (based on the three DALL-E theme concepts explored in Part 1)

  static const AppPalette tpDark = AppPalette(
    name: 'TP Dark',
    isDark: true,
    accent: Color(0xFFE11D2B),
    accentLight: Color(0xFFFF3B3B),
    bg: Color(0xFF121212),
    cardBg: Color(0xFF1E1E1E),
    border: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
  );

  static const AppPalette tpLight = AppPalette(
    name: 'TP Light',
    isDark: false,
    accent: Color(0xFFC41522),
    // slightly darker red so it stays readable on white
    accentLight: Color(0xFFE11D2B),
    bg: Color(0xFFF5F5F7),
    cardBg: Color(0xFFFFFFFF),
    border: Color(0xFFE2E2E6),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF63636B),
  );

  static const AppPalette midnightPurple = AppPalette(
    name: 'Midnight Purple',
    isDark: true,
    accent: Color(0xFF8B5CF6),
    accentLight: Color(0xFFA78BFA),
    bg: Color(0xFF120F1C),
    cardBg: Color(0xFF1C1729),
    border: Color(0xFF2E2545),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB3ABC7),
  );

  static const List<AppPalette> palettes = [tpDark, tpLight, midnightPurple];

  // ----- the colours the whole app reads -----
  // they start as TP Dark and get reassigned by applyPalette()
  // (the names tpRed/darkBg are kept from Part 2 so no screen needed
  // renaming - tpRed simply means "the accent colour" now)

  static AppPalette current = tpDark;
  static Color tpRed = tpDark.accent;
  static Color tpRedLight = tpDark.accentLight;
  static Color darkBg = tpDark.bg;
  static Color darkCardBg = tpDark.cardBg;
  static Color darkBorder = tpDark.border;
  static Color textPrimary = tpDark.textPrimary;
  static Color textSecondary = tpDark.textSecondary;

  // swaps every colour to the given palette
  static void applyPalette(AppPalette palette) {
    current = palette;
    tpRed = palette.accent;
    tpRedLight = palette.accentLight;
    darkBg = palette.bg;
    darkCardBg = palette.cardBg;
    darkBorder = palette.border;
    textPrimary = palette.textPrimary;
    textSecondary = palette.textSecondary;
  }

  // finds a palette by its saved name, falls back to TP Dark
  static AppPalette paletteByName(String name) {
    return palettes.firstWhere(
      (p) => p.name == name,
      orElse: () => tpDark,
    );
  }

  // kept so existing code that says AppTheme.darkTheme still works
  static ThemeData get darkTheme => theme;

  // builds the MaterialApp theme from whatever palette is active
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: current.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCardBg,
        selectedItemColor: tpRed,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: darkCardBg,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tpRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tpRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tpRed,
          side: BorderSide(color: tpRed),
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
