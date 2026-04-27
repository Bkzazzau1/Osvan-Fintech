// Removed: import 'package:flutter/material.dart' show TargetPlatform;
// We rely on kIsWeb and Dart defines instead of TargetPlatform.android

/// Backend URL config.
///
/// Default points to production (https://fintech.osvan.africa) — no trailing /api.
/// Override at runtime with --dart-define, e.g.:
///   flutter run --dart-define=OSVAN_API_BASE=http://127.0.0.1:8000
///   flutter run -d emulator-5554 --dart-define=OSVAN_API_BASE=http://10.0.2.2:8000
class Env {
  /// Compile-time constant, safe in const constructors.
  /// Defaults to the production API URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'OSVAN_API_BASE',
    defaultValue:
        'https://fintech.osvan.africa', // ✅ production default (no /api)
  );

  /// Runtime URL used by the API client.
  ///
  /// This getter will now always return the base URL defined by the Dart-define
  /// or the production default, preventing automatic switching to 10.0.2.2:8000
  /// when running on an emulator unless manually specified.
  static String get autoBaseUrl {
    // Always use the compile-time constant (which defaults to production)
    // unless an explicit dart-define override was provided.
    return apiBaseUrl;

    // NOTE: The previous logic (removed below) was causing timeouts
    // because it automatically switched to a local URL (10.0.2.2:8000)
    // without confirming a local Django server was running.

    /* REMOVED PREVIOUS LOGIC:
    // Respect compile-time override if defined
    if (apiBaseUrl != 'https://fintech.osvan.africa') return apiBaseUrl;

    // Web keeps prod default unless overridden
    if (kIsWeb) return apiBaseUrl;

    // Android emulator local dev (the client handles path segments itself)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // This caused the timeout!
    }
    return apiBaseUrl;
    */
  }
}
