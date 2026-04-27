// lib/services/auth_service.dart
//
// Centralized auth helper built on top of ApiClient + SessionStore.
// - Primary login: POST /api/token/login/  (email-first)
// - Fallbacks kept for resilience (/api/token/, djoser, custom v1)
// - IMPORTANT FIX:
//   Fail fast on auth failures even when Dio validateStatus allows 4xx.
//

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:osvan_app/services/api_client.dart';
import 'package:osvan_app/store/session_store.dart';

class AuthService {
  /// Optional bootstrap (safe to call multiple times)
  static Future<void> init() async {
    await SessionStore.init();
    await ApiClient.ensureInitialized();
  }

  static Future<String?> getToken() => SessionStore.instance.access;
  static Future<String?> getRefresh() => SessionStore.instance.refresh;

  static Future<void> setTokens({String? access, String? refresh}) async {
    if (access == null && refresh == null) return;
    await SessionStore.instance.saveTokens(
      access: access ?? (await SessionStore.instance.access) ?? '',
      refresh: refresh,
    );
  }

  static Future<void> clear() => SessionStore.instance.clear();
  static Future<bool> isLoggedIn() => SessionStore.instance.isLoggedIn;

  static bool _isDefinitiveAuthFailure(int? code) {
    return code == 400 || code == 401 || code == 403;
  }

  static String _humanMessageFromResponse(dynamic data, int? statusCode) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null) {
        final s = detail.toString().trim();
        if (s.isNotEmpty) return s;
      }

      for (final k in ['password', 'username', 'email', 'non_field_errors']) {
        final v = data[k];
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }

    if (statusCode == 401) return 'Wrong email or password.';
    if (statusCode == 403) return 'Account disabled.';
    if (statusCode == 400) return 'Invalid login details.';
    return 'Login failed';
  }

  static Map<String, dynamic> _mapOrEmpty(dynamic data) =>
      (data is Map<String, dynamic>) ? data : <String, dynamic>{};

  static Map<String, dynamic> _unwrap(dynamic data) {
    final m = _mapOrEmpty(data);
    if (m['data'] is Map<String, dynamic>) {
      return m['data'] as Map<String, dynamic>;
    }
    return m;
  }

  /// Returns the raw response map and persists tokens when present.
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String email,
  }) async {
    await init();
    final dio = ApiClient.shared.dio;

    // Primary + fallbacks (relative to dio.baseUrl)
    const endpoints = <String>[
      ApiPaths.tokenLogin, // "/api/token/login/"
      ApiPaths.obtain, // "/api/token/"
      '/auth/jwt/create/',
      '/v1/auth/login/',
      '/auth/login/',
    ];

    final uname = (username.isNotEmpty ? username : email).trim();

    List<Map<String, dynamic>> shapesFor(String path) {
      if (path == ApiPaths.obtain) {
        // /api/token/ usually expects "username"
        return [
          {'username': email.trim(), 'password': password},
          {'username': uname, 'password': password},
          {'email': email.trim(), 'password': password},
        ];
      }
      // /api/token/login/ prefers email
      return [
        {'email': email.trim(), 'password': password},
        {'username': email.trim(), 'password': password},
        {'username': uname, 'password': password},
      ];
    }

    // Ensure interceptor won’t attach Authorization on these calls
    final noAuth = Options(
      headers: const {'X-Skip-Auth': '1', 'Content-Type': 'application/json'},
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    );

    DioException? lastErr;

    for (final path in endpoints) {
      final shapes = shapesFor(path);

      for (final body in shapes) {
        try {
          final r = await dio.post(path, data: body, options: noAuth);

          final status = r.statusCode;
          final raw = _mapOrEmpty(r.data);
          final flat = _unwrap(raw);

          // ✅ FAIL FAST: If 400/401/403 returned as "success" due to validateStatus
          if (_isDefinitiveAuthFailure(status)) {
            final msg = _humanMessageFromResponse(r.data, status);
            throw DioException(
              requestOptions: r.requestOptions,
              response: r,
              type: DioExceptionType.badResponse,
              message: msg,
              error: msg,
            );
          }

          // ✅ FAIL FAST: backend error shape (DRF)
          final detail = (flat['detail'] ?? raw['detail'])?.toString().trim();
          if (detail != null && detail.isNotEmpty) {
            throw DioException(
              requestOptions: r.requestOptions,
              response: r,
              type: DioExceptionType.badResponse,
              message: detail,
              error: detail,
            );
          }

          final access =
              (flat['access'] ?? flat['token'] ?? flat['access_token'])
                  ?.toString();
          final refresh =
              (flat['refresh'] ?? flat['refresh_token'])?.toString();

          if (access != null && access.isNotEmpty) {
            await SessionStore.instance
                .saveTokens(access: access, refresh: refresh);
            return raw;
          }

          // ✅ No token in response → treat as failure immediately (don’t loop)
          throw DioException(
            requestOptions: r.requestOptions,
            response: r,
            type: DioExceptionType.badResponse,
            message: 'Login response missing access token',
            error: 'Login response missing access token',
          );
        } on DioException catch (e) {
          lastErr = e;

          // If definitive auth failure, stop immediately (don’t try other endpoints)
          final code = e.response?.statusCode;
          if (_isDefinitiveAuthFailure(code)) rethrow;

          // Otherwise continue trying next shape/endpoint (404, network, etc.)
        }
      }
    }

    if (lastErr != null) throw lastErr;

    throw DioException(
      requestOptions: RequestOptions(path: ApiPaths.tokenLogin),
      message: 'Login failed',
    );
  }

  static Future<void> logout({bool notifyServer = true}) async {
    await init();

    if (notifyServer) {
      final dio = ApiClient.shared.dio;
      final refresh = await getRefresh();

      final candidates = <String>[
        '/v1/auth/logout/',
        '/auth/logout/',
        '/token/blacklist/',
      ];

      for (final path in candidates) {
        try {
          await dio.post(path, data: {'refresh': refresh});
          break;
        } catch (_) {}
      }
    }

    await clear();
  }
}
