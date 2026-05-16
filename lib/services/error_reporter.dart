import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      recordFlutterError(details, fatal: true);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true, context: 'platform');
      return true;
    };
  }

  void recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) {
    recordError(
      details.exception,
      details.stack,
      fatal: fatal,
      context: details.context?.toDescription(),
      metadata: {
        'library': details.library,
        'silent': details.silent,
      },
    );
  }

  void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
    Map<String, Object?> metadata = const {},
  }) {
    final sanitized = _sanitizeMetadata(metadata);

    if (kDebugMode) {
      developer.log(
        fatal ? 'Fatal error' : 'Non-fatal error',
        name: 'ErrorReporter${context == null ? '' : '.$context'}',
        error: error,
        stackTrace: stack,
      );
      if (sanitized.isNotEmpty) {
        developer.log(
          sanitized.toString(),
          name: 'ErrorReporter.metadata',
        );
      }
    }

    // Hook point for Sentry/Firebase Crashlytics:
    // - Sentry.captureException(error, stackTrace: stack)
    // - FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal)
  }

  void recordApiFailure(
    DioException error, {
    String? feature,
  }) {
    final req = error.requestOptions;
    recordError(
      error,
      error.stackTrace,
      fatal: false,
      context: 'api',
      metadata: {
        'feature': feature,
        'method': req.method,
        'path': Uri.tryParse(req.path)?.path ?? req.path,
        'statusCode': error.response?.statusCode,
        'type': error.type.name,
      },
    );
  }

  Map<String, Object?> _sanitizeMetadata(Map<String, Object?> metadata) {
    final out = <String, Object?>{};
    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('token') ||
          key.contains('authorization') ||
          key.contains('password') ||
          key.contains('pin')) {
        continue;
      }
      out[entry.key] = entry.value;
    }
    return out;
  }
}
