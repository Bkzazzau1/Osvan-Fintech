import 'package:flutter/material.dart';

import 'colors.dart';

// Light Theme
final ThemeData osvanLightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: osvanWhite,
  primaryColor: osvanGreen,
  colorScheme: ColorScheme.light(
    primary: osvanGreen,
    onPrimary: osvanWhite,
    secondary: osvanBlue,
    onSecondary: osvanWhite,
    surface: osvanWhite,
    onSurface: osvanBlack,
    error: osvanRed,
    onError: osvanWhite,
    outline: osvanGrey.withValues(alpha: 0.35),
  ),
  cardTheme: CardThemeData(
    color: osvanWhite,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: osvanGrey.withValues(alpha: 0.2)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: osvanWhite,
    foregroundColor: osvanBlack,
    elevation: 0,
    iconTheme: IconThemeData(color: osvanGreen),
    titleTextStyle: TextStyle(
      color: osvanBlack,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: osvanGreen,
      foregroundColor: osvanWhite,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    labelStyle: const TextStyle(color: osvanBlack),
    hintStyle: TextStyle(color: osvanBlack.withValues(alpha: 0.6)),
    filled: true,
    fillColor: osvanGrey.withValues(alpha: 0.12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: osvanGrey.withValues(alpha: 0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: osvanGrey.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: osvanGreen, width: 1.4),
    ),
  ),
  iconTheme: const IconThemeData(color: osvanGreen),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: osvanBlack, fontSize: 16),
    bodyMedium: TextStyle(color: osvanBlack, fontSize: 14),
    bodySmall: TextStyle(color: osvanGrey, fontSize: 12),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      color: osvanBlack,
    ),
  ),
);

// Dark Theme (as per screenshot)
final ThemeData osvanDarkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: osvanDarkBackground,
  primaryColor: osvanDarkAccent,
  colorScheme: ColorScheme.dark(
    primary: osvanDarkAccent,
    onPrimary: osvanDarkBackground,
    secondary: osvanBlue,
    onSecondary: osvanWhite,
    surface: osvanDarkCard,
    onSurface: osvanWhite,
    error: osvanRed,
    onError: osvanWhite,
    outline: Colors.white24,
  ),
  cardTheme: CardThemeData(
    color: osvanDarkCard,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Colors.white12),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: osvanDarkCard,
    foregroundColor: osvanWhite,
    elevation: 0,
    iconTheme: IconThemeData(color: osvanWhite),
    titleTextStyle: TextStyle(
      color: osvanWhite,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: osvanDarkAccent,
      foregroundColor: osvanDarkBackground,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    labelStyle: const TextStyle(color: osvanWhite),
    hintStyle: TextStyle(color: Colors.white70),
    filled: true,
    fillColor: osvanBlack.withValues(alpha: 0.2),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: osvanDarkAccent, width: 1.4),
    ),
  ),
  iconTheme: const IconThemeData(color: osvanWhite),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: osvanWhite, fontSize: 16),
    bodyMedium: TextStyle(color: osvanWhite, fontSize: 14),
    bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w700,
      color: osvanWhite,
    ),
  ),
);
