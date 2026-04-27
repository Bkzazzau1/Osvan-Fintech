// lib/app.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// Routes & pages
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/core/theme.dart';

// If you used the old flow import here, it must be removed:
// ❌ import 'package:osvan_app/screen/transfer/view/send_money_flow.dart';
// Use the new split views only if you instantiate them directly here (we don't).
// If you really need a direct reference for a debug home, uncomment this:
// import 'package:osvan_app/screen/transfer/view/send_money_destination_view.dart';

class OsvanApp extends StatelessWidget {
  const OsvanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Osvan',
      debugShowCheckedModeBanner: false,

      // Use centralized routes
      initialRoute: AppRoutes.welcome,
      getPages: AppRoutes.pages,

      // Basic light/dark themes (kept minimal; your app theme files can replace these)
      theme: osvanLightTheme,
      darkTheme: osvanDarkTheme,

      // If you previously used `home:` or a direct widget here, remove it.
      // We rely on initialRoute + getPages. Example (dev only):
      // home: const SendMoneyDestinationView(),
    );
  }
}
