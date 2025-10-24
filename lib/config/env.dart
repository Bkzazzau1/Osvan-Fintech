// lib/config/env.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;

/// Backend URL config.
///
/// Default points to production (https://fintech.osvan.africa) — no trailing /api.
/// Override at runtime with --dart-define, e.g.:
///   flutter run --dart-define=OSVAN_API_BASE=http://127.0.0.1:8000
///   flutter run -d emulator-5554 --dart-define=OSVAN_API_BASE=http://10.0.2.2:8000
class Env {
  /// Compile-time constant, safe in const constructors.
  static const String apiBaseUrl = String.fromEnvironment(
    'OSVAN_API_BASE',
    defaultValue:
        'https://fintech.osvan.africa', // ✅ production default (no /api)
  );

  /// Runtime fallback for emulator/local dev if no --dart-define is used.
  static String get autoBaseUrl {
    // Respect compile-time override if defined
    if (apiBaseUrl != 'https://fintech.osvan.africa') return apiBaseUrl;

    // Web keeps prod default unless overridden
    if (kIsWeb) return apiBaseUrl;

    // Android emulator local dev (the client handles path segments itself)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // ✅ no /api
    }
    return apiBaseUrl;
  }
}
