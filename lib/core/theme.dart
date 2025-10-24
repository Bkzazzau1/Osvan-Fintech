import 'package:flutter/material.dart';

import 'colors.dart';

// Light Theme
final ThemeData osvanLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: osvanWhite,
  primaryColor: osvanGreen,
  cardColor: osvanWhite,
  appBarTheme: const AppBarTheme(
    backgroundColor: osvanWhite,
    elevation: 0,
    iconTheme: IconThemeData(color: osvanBlack),
    titleTextStyle: TextStyle(
      color: osvanBlack,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: osvanGreen,
      foregroundColor: osvanWhite,
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: osvanBlack),
    bodySmall: TextStyle(color: osvanGrey),
  ),
);

// Dark Theme (as per screenshot)
final ThemeData osvanDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: osvanDarkBackground,
  primaryColor: osvanDarkAccent,
  cardColor: osvanDarkCard,
  appBarTheme: const AppBarTheme(
    backgroundColor: osvanDarkCard,
    elevation: 0,
    iconTheme: IconThemeData(color: osvanWhite),
    titleTextStyle: TextStyle(
      color: osvanWhite,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: osvanDarkAccent,
      foregroundColor: osvanDarkBackground,
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: osvanWhite),
    bodySmall: TextStyle(color: Colors.white70),
  ),
);
