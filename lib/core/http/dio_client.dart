// lib/core/http/dio_client.dart
//
// Centralized lightweight Dio builder
// - Uses Riverpod baseUrlProvider (falls back to kApiBaseUrl)
// - Injects Authorization from secure storage/GetStorage (unless X-Skip-Auth: 1)
// - Adds LogInterceptor in debug builds
// - Keep token refresh logic in ApiClient; this is a simple, shared HTTP client

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/config/api.dart';

final _secure = const FlutterSecureStorage();
final _box = GetStorage();

/// Read access token from secure storage or fallback to GetStorage.
Future<String?> _readAccessToken() async {
  final fromSecure = await _secure.read(key: 'access');
  if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;

  final fromBox = _box.read<String>('access');
  return (fromBox != null && fromBox.isNotEmpty) ? fromBox : null;
}

/// Build a Dio instance for direct or service use.
/// - `attachAuth`: if true, automatically attaches Bearer token unless X-Skip-Auth is set.
/// - `withLogging`: enables LogInterceptor in debug mode.
Dio buildDio({
  String? baseUrl,
  bool attachAuth = true,
  bool withLogging = true,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: (baseUrl ?? kApiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  // Authorization header injector
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (attachAuth) {
          final skipAuth = options.headers['X-Skip-Auth']?.toString() == '1';

          if (!skipAuth) {
            final token = await _readAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers.remove('Authorization');
          }
        }
        handler.next(options);
      },
    ),
  );

  // Logging interceptor (debug only)
  if (withLogging && kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  return dio;
}

/// Riverpod provider — preferred way to access Dio inside app code.
/// Use: `final dio = ref.read(dioProvider);`
final dioProvider = Provider<Dio>((ref) {
  final base = ref.watch(baseUrlProvider);
  return buildDio(baseUrl: base, attachAuth: true, withLogging: true);
});
