import 'package:flutter/material.dart';

TextTheme buildAppTextTheme() {
  const bodyTheme = TextTheme(
    bodyLarge: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.45,
      letterSpacing: 0.1,
    ),
    labelLarge: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    labelSmall: TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );

  return bodyTheme.copyWith(
    displaySmall: const TextStyle(
      fontFamily: 'ThmanyahSerifDisplay',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'ThmanyahSerifDisplay',
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineSmall: const TextStyle(
      fontFamily: 'ThmanyahSerifDisplay',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'ThmanyahSerifDisplay',
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleSmall: const TextStyle(
      fontFamily: 'ThmanyahSans',
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  );
}
