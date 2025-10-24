// lib/controller/theme_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  /// Toggle with switch input (true = dark, false = light)
  void toggleTheme(bool isDark) {
    _themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    update(); // Notifies GetBuilder
  }

  /// Toggle without input, used with icons
  void toggle() {
    _themeMode.value = _themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    update();
  }

  /// Returns true if current mode is dark
  bool get isDarkMode => _themeMode.value == ThemeMode.dark;

  /// Optional: Auto-detect system preference at startup
  @override
  void onInit() {
    final Brightness systemBrightness =
        // ignore: deprecated_member_use
        WidgetsBinding.instance.window.platformBrightness;
    _themeMode.value = systemBrightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    super.onInit();
  }
}
