import 'package:flutter/material.dart';

/// Material 3 theme generated from a seed colour. Each technology screen can
/// re-seed the theme with its own brand colour, which is why this is a
/// function rather than a constant.
ThemeData buildTheme({required Color seed, required Brightness brightness}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
    ),
  );
}

/// Palette for the three seniority levels. Kept apart from the seeded scheme
/// so "junior/mid/senior" reads the same on every technology.
extension SeniorityColors on ColorScheme {
  Color levelColor(int levelIndex) => switch (levelIndex) {
    0 => const Color(0xFF2E7D32),
    1 => const Color(0xFFE65100),
    _ => const Color(0xFF6A1B9A),
  };
}
