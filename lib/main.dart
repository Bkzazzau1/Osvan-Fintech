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
import 'package:osvan_app/controller/theme_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
// ✅ Services / Controllers we must register at startup
import 'package:osvan_app/screen/wallet/services/config_service.dart';
import 'package:osvan_app/services/api_client.dart';

// Debug-only smoke test for /api/token/ (safe: runs only in debug)
import 'auth_test.dart' show testEmailLogin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wrap startup in a guarded zone to avoid silent crashes in release
  await runZonedGuarded<Future<void>>(() async {
    // 1) Load env (non-fatal if missing)
    try {
      await dotenv.load(fileName: '.env.production');
    } catch (_) {
      // ignore missing env file in non-prod flavors
    }

    // 2) Init local KV store (used by tokens/config/user prefs)
    await GetStorage.init();

    // 3) Initialize ConfigService & register it for GetX lookups
    await ConfigService.init(); // loads flags/rates if you implemented it so
    Get.put<ConfigService>(
        ConfigService()); // ✅ ensure Get.find<ConfigService>() works

    // 4) Initialize API client singleton before any controller uses it
    await ApiClient.ensureInitialized();

    // 5) Register core controllers available app-wide
    Get.put<ThemeController>(ThemeController());
    Get.put<WalletsController>(WalletsController(),
        permanent: true); // ✅ dashboard can resolve immediately

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

    runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Osvan',
          themeMode: themeController.themeMode,

          // Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: osvanWhite,
            primaryColor: osvanGreen,
            fontFamily: 'Poppins',
            cardColor: osvanWhite,
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: osvanBlack),
              filled: true,
              fillColor: osvanGrey.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: osvanBlack, fontSize: 16),
              bodyMedium: TextStyle(color: osvanBlack, fontSize: 14),
              titleLarge: TextStyle(
                fontWeight: FontWeight.bold,
                color: osvanBlack,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: osvanWhite,
              elevation: 0,
              iconTheme: IconThemeData(color: osvanBlack),
              titleTextStyle: TextStyle(
                color: osvanBlack,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          // Dark Theme
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: osvanDarkBackground,
            primaryColor: osvanDarkAccent,
            fontFamily: 'Poppins',
            cardColor: osvanDarkCard,
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: osvanWhite),
              filled: true,
              fillColor: osvanBlack.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: osvanWhite, fontSize: 16),
              bodyMedium: TextStyle(color: osvanWhite, fontSize: 14),
              titleLarge: TextStyle(
                fontWeight: FontWeight.bold,
                color: osvanWhite,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: osvanDarkCard,
              elevation: 0,
              iconTheme: IconThemeData(color: osvanWhite),
              titleTextStyle: TextStyle(
                color: osvanWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          // Routes
          initialRoute: AppRoutes.welcome,
          getPages: AppRoutes.pages,
        );
      },
    );
  }
}
