import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.clay,
    onPrimary: Colors.white,
    secondary: AppColors.pine,
    onSecondary: Colors.white,
    tertiary: AppColors.sky,
    onTertiary: Colors.white,
    error: AppColors.rose,
    onError: Colors.white,
    surface: AppColors.cloud,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.sand,
    onSurfaceVariant: AppColors.slate,
    outline: AppColors.mist,
    outlineVariant: AppColors.mist,
    shadow: Color(0x1F121826),
    scrim: Color(0x66121826),
    inverseSurface: AppColors.midnight,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.amber,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'ThmanyahSans',
    fontFamilyFallback: appFontFallback,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.fog,
    textTheme: buildAppTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cloud,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      shadowColor: AppColors.ink.withValues(alpha: 0.06),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.mist),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      hintStyle: TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
        color: AppColors.slate.withValues(alpha: 0.78),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
      ),
      helperStyle: const TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
      ),
      errorStyle: const TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.sky, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.midnight,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'ThmanyahSans',
          fontFamilyFallback: appFontFallback,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.midnight,
        textStyle: const TextStyle(
          fontFamily: 'ThmanyahSans',
          fontFamilyFallback: appFontFallback,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: AppColors.mist),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'ThmanyahSans',
            fontFamilyFallback: appFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      deleteIconColor: AppColors.slate,
      disabledColor: AppColors.mist,
      selectedColor: AppColors.sand,
      secondarySelectedColor: AppColors.sand,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: AppColors.mist),
      labelStyle: const TextStyle(
        fontFamilyFallback: appFontFallback,
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cloud.withValues(alpha: 0.94),
      indicatorColor: AppColors.sand,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamilyFallback: appFontFallback,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.midnight,
      contentTextStyle: const TextStyle(
        fontFamily: 'ThmanyahSans',
        fontFamilyFallback: appFontFallback,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
  );
}
