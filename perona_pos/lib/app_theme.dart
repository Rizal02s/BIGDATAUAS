import 'package:flutter/material.dart';

abstract final class PeronaColors {
  static const ink = Color(0xff252a26);
  static const muted = Color(0xff687169);
  static const forest = Color(0xff58730b);
  static const brandGreen = Color(0xff8cb719);
  static const lime = Color(0xffedf4df);
  static const background = Color(0xfffafbf8);
  static const surface = Color(0xffffffff);
  static const border = Color(0xffe3e7e0);
}

ThemeData peronaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PeronaColors.forest,
    brightness: Brightness.light,
    primary: PeronaColors.forest,
    onPrimary: Colors.white,
    secondary: PeronaColors.lime,
    onSecondary: PeronaColors.ink,
    surface: PeronaColors.surface,
    onSurface: PeronaColors.ink,
    onSurfaceVariant: PeronaColors.muted,
    surfaceContainerLowest: PeronaColors.surface,
    surfaceContainerLow: PeronaColors.background,
    surfaceContainer: Color(0xfff2f4ef),
    surfaceContainerHigh: Color(0xffeef1eb),
    surfaceContainerHighest: Color(0xffe8ece4),
    outline: PeronaColors.muted,
    outlineVariant: PeronaColors.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  final textTheme = base.textTheme
      .copyWith(
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          letterSpacing: 0,
        ),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, letterSpacing: 0),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: 0,
        ),
      )
      .apply(
        fontFamily: 'Roboto',
        bodyColor: PeronaColors.ink,
        displayColor: PeronaColors.ink,
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return base.copyWith(
    scaffoldBackgroundColor: PeronaColors.background,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: PeronaColors.background,
      foregroundColor: PeronaColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: PeronaColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: rounded.copyWith(
        side: const BorderSide(color: PeronaColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PeronaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PeronaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PeronaColors.forest, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: PeronaColors.ink,
        backgroundColor: PeronaColors.brandGreen,
        textStyle: textTheme.titleMedium,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PeronaColors.forest),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PeronaColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: PeronaColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        foregroundColor: const WidgetStatePropertyAll(PeronaColors.ink),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? PeronaColors.lime
                  : PeronaColors.surface,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: PeronaColors.border),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PeronaColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PeronaColors.lime,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
          color:
              states.contains(WidgetState.selected)
                  ? PeronaColors.forest
                  : PeronaColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color:
              states.contains(WidgetState.selected)
                  ? PeronaColors.forest
                  : PeronaColors.muted,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PeronaColors.lime,
      foregroundColor: PeronaColors.ink,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(color: PeronaColors.border, space: 24),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
