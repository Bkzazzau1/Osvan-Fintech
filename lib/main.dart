// lib/main.dart
// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'dart:async' show runZonedGuarded, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/controller/auth_controller.dart';
import 'package:osvan_app/controller/theme_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/core/theme.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
// ✅ Services / Controllers we must register at startup
import 'package:osvan_app/screen/wallet/services/config_service.dart';
import 'package:osvan_app/services/api_client.dart';
// 🔐 auth bootstrap (centralized token store)
import 'package:osvan_app/store/session_store.dart';

// Debug-only smoke test for /api/token/ (safe: runs only in debug)
import 'auth_test.dart' show testEmailLogin;

Future<void> main() async {
  // Wrap startup in a guarded zone to avoid silent crashes in release
  await runZonedGuarded<Future<void>>(() async {
    // IMPORTANT: initialize bindings inside this same zone
    WidgetsFlutterBinding.ensureInitialized();

    // 1) Load env (non-fatal if missing)
    try {
      await dotenv.load(fileName: '.env.production');
    } catch (_) {
      // ignore missing env file in non-prod flavors
    }

    // 2) Init local KV store (used by tokens/config/user prefs)
    await GetStorage.init();

    // 2b) 🔐 Init centralized token store (safe on web & mobile)
    await SessionStore.init();

    // 3) Initialize ConfigService & register it for GetX lookups
    await ConfigService.init(); // loads flags/rates if implemented
    Get.put<ConfigService>(
        ConfigService()); // ensure Get.find<ConfigService>() works

    // 4) Initialize API client singleton before any controller uses it
    await ApiClient.ensureInitialized();

    // 4b) 🔐 Make AuthController available app-wide
    Get.put<AuthController>(AuthController(), permanent: true).init();

    // 5) Register core controllers available app-wide
    Get.put<ThemeController>(ThemeController());
    Get.put<WalletsController>(WalletsController(), permanent: true);

    // Force welcome as the first page (even if a session exists)
    const String startRoute = AppRoutes.welcome;

    // 6) Optional diagnostics in debug builds
    if (kDebugMode) {
      final box = GetStorage();
      final cfg = Get.find<ConfigService>();

      // ignore: avoid_print
      print('Backend URL (Env.apiBaseUrl): ${Env.apiBaseUrl}');
      // ignore: avoid_print
      print('Access token (local): ${box.read('access')}');
      // ignore: avoid_print
      print('Refresh token (local): ${box.read('refresh')}');
      // ignore: avoid_print
      print(
          'Config flags: fund=${cfg.cardsFundEnabled}, withdraw=${cfg.cardsWithdrawEnabled}, usdOnly=${cfg.usdCardOnly}, fee=${cfg.conversionFeePct}');
      // ignore: avoid_print
      print('FX USD->NGN: ${cfg.rateFor('NGN')}');

      // Fire-and-forget health ping + login smoke (does not block startup)
      unawaited(_debugPing());
      try {
        unawaited(testEmailLogin());
      } catch (_) {
        // If auth_test.dart is absent in some flavors, ignore gracefully
      }
    }

    // 7) System UI styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: osvanGreen,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: osvanGreen,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(MyApp(initialRoute: startRoute));
  }, (error, stack) {
    // Last line of defense logging; replace with your logger if needed
    if (kDebugMode) {
      // ignore: avoid_print
      print('Uncaught zone error: $error\n$stack');
    }
  });
}

Future<void> _debugPing() async {
  try {
    final ok = await ApiClient.shared.ping();
    // ignore: avoid_print
    print('API health ping ok? $ok');
  } catch (e) {
    // ignore: avoid_print
    print('API health ping failed: $e');
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Osvan',
          themeMode: themeController.themeMode,

          theme: osvanLightTheme,
          darkTheme: osvanDarkTheme,

          // Routes
          initialRoute: initialRoute,
          getPages: AppRoutes.pages,
        );
      },
    );
  }
}
