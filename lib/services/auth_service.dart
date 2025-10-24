// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/config/env.dart';

class AuthService {
  // ---- storage (web & mobile via GetStorage) ----
  static final GetStorage _box = GetStorage();

  /// Init storage early in app bootstrap (e.g., in main()).
  static Future<void> init() async {
    await GetStorage.init();
    await _box.writeIfNull('__init__', true);
  }

  // ---- token helpers ----
  static Future<String?> getToken() async =>
      _box.read<String>('access') ?? _box.read<String>('token');

  static Future<String?> getRefresh() async => _box.read<String>('refresh');

  static Future<void> setTokens({String? access, String? refresh}) async {
    if (access != null) {
      await _box.write('access', access);
      await _box.write('token', access); // backward compat
    }
    if (refresh != null) {
      await _box.write('refresh', refresh);
    }
  }

  static Future<void> clear() async {
    await _box.remove('access');
    await _box.remove('token');
    await _box.remove('refresh');
  }

  static Future<bool> isLoggedIn() async =>
      (await getToken())?.isNotEmpty == true;

  // ---- Username/password login (primary = email) ----
  //
  // Primary (Django SimpleJWT):
  //   POST /api/token/  -> { "access": "...", "refresh": "..." }
  //
  // We try a few payload shapes to be resilient across backends. For /token/,
  // we send username=<email> first because the live API requires `username`.
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String email,
  }) async {
    final base = _ensureApiSuffix(_normalizeBaseUrl(Env.autoBaseUrl));

    final dio = Dio(BaseOptions(
      baseUrl: base, // e.g. https://fintech.osvan.africa/api
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        // ensure no stale token goes out
        'Authorization': null,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // ---- minimal extras: request logging + quick reachability check ----
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // avoid dumping tokens
    ));

    // Optional connectivity check (non-fatal); your server exposes /api/health/
    try {
      await dio.get('/health/',
          options: Options(headers: {'X-Skip-Auth': '1'}));
    } catch (_) {
      // ignore; we still try login endpoints next
    }

    // Endpoints are relative to /api
    final endpoints = <String>[
      '/token/', // SimpleJWT std (your live endpoint)
      '/auth/jwt/create/', // djoser/jwt
      '/v1/auth/login/', // custom v1
      '/auth/login/', // generic
    ];

    // Most backends accept either email or username; for /token/ the server
    // wants "username", so we try username=email first.
    final uname = (username.isNotEmpty ? username : email).trim();

    List<Map<String, dynamic>> shapesFor(String path) {
      if (path == '/token/') {
        // **IMPORTANT**: server expects `username`
        return [
          {'username': email.trim(), 'password': password}, // ← FIRST
          {'username': uname, 'password': password},
          {'email': email.trim(), 'password': password},
        ];
      }
      // other endpoints—try email first, then username fallbacks
      return [
        {'email': email.trim(), 'password': password},
        {'username': email.trim(), 'password': password},
        {'username': uname, 'password': password},
      ];
    }

    DioException? lastDio;

    for (final path in endpoints) {
      final shapes = shapesFor(path);
      for (final body in shapes) {
        try {
          final r = await dio.post<Map<String, dynamic>>(
            path,
            data: body,
            options: Options(headers: {
              'X-Skip-Auth': '1', // <- prevent Authorization injection
            }),
          );

          final data = r.data ?? <String, dynamic>{};
          // Handle wrappers like { "data": { ... } }
          final map = (data['data'] is Map) ? (data['data'] as Map) : data;

          final access = (map['access'] ?? map['token'] ?? map['access_token'])
              ?.toString()
              .trim();
          final refresh = map['refresh']?.toString().trim();

          if ((access != null && access.isNotEmpty)) {
            await setTokens(access: access, refresh: refresh);
            return Map<String, dynamic>.from(data);
          }

          // No tokens returned → treat as error and try next shape/endpoint
          lastDio = DioException.badResponse(
            statusCode: r.statusCode ?? 400,
            requestOptions: r.requestOptions,
            response: r,
          );
        } on DioException catch (e) {
          lastDio = e; // try next shape or endpoint
        }
      }
    }

    // Exhausted attempts
    if (lastDio != null) throw lastDio;
    throw DioException(
      requestOptions: RequestOptions(path: '$base/token/'),
      message: 'Login failed',
    );
  }

  // ---- logout (optional server notify) ----
  static Future<void> logout({bool notifyServer = true}) async {
    final access = await getToken();
    final refresh = await getRefresh();

    if (notifyServer && (access != null || refresh != null)) {
      final base = _ensureApiSuffix(_normalizeBaseUrl(Env.autoBaseUrl));
      final dio = Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          if (access != null) 'Authorization': 'Bearer $access',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final endpoints = <String>[
        '/v1/auth/logout/',
        '/auth/logout/',
        '/token/blacklist/', // SimpleJWT blacklist
      ];

      for (final path in endpoints) {
        try {
          await dio.post<Map<String, dynamic>>(
            path,
            data: jsonEncode({'refresh': refresh}),
            options: Options(headers: {
              if (access != null) 'Authorization': 'Bearer $access',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            }),
          );
          break;
        } catch (_) {
          // swallow and try next
        }
      }
    }

    await clear();
  }

  // ---- utils ----
  static String _normalizeBaseUrl(String base) {
    if (base.isEmpty) return '';
    return base.replaceAll(RegExp(r'/+$'), ''); // trim trailing slashes
  }

  static String _ensureApiSuffix(String root) {
    return root.endsWith('/api') ? root : '$root/api';
  }
}

// ---- (Optional) auto-attach & refresh helpers ------------------------------
extension AuthDio on AuthService {
  static void attachJwtRefresh(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final access = await AuthService.getToken();
          if (access != null && access.isNotEmpty) {
            opts.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(opts);
        },
        onError: (e, handler) async {
          final is401 = e.response?.statusCode == 401;
          final hadAuth = e.requestOptions.headers['Authorization'] != null;
          if (is401 && hadAuth) {
            final newAccess = await _tryRefresh(dio);
            if (newAccess != null) {
              final retried =
                  await _retryWithNewToken(dio, e.requestOptions, newAccess);
              return handler.resolve(retried);
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  static Future<String?> _tryRefresh(Dio dio) async {
    final refresh = await AuthService.getRefresh();
    if (refresh == null || refresh.isEmpty) return null;

    final base = dio.options.baseUrl.isNotEmpty
        ? dio.options.baseUrl
        : AuthService._ensureApiSuffix(
            AuthService._normalizeBaseUrl(Env.autoBaseUrl),
          );

    final endpoints = <String>[
      '$base/token/refresh/',
      '$base/auth/jwt/refresh/',
      '$base/v1/auth/refresh/',
      '$base/auth/refresh/',
    ];

    for (final url in endpoints) {
      try {
        final r = await dio.post<Map<String, dynamic>>(
          url,
          data: {'refresh': refresh},
          options: Options(headers: {'Authorization': null}),
        );
        if (r.statusCode == 200 && r.data is Map) {
          final data = r.data!;
          final map = (data['data'] is Map) ? (data['data'] as Map) : data;
          final access = map['access']?.toString();
          if (access != null && access.isNotEmpty) {
            await AuthService.setTokens(access: access);
            return access;
          }
        }
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  static Future<Response<dynamic>> _retryWithNewToken(
    Dio dio,
    RequestOptions o,
    String access,
  ) {
    final headers = Map<String, dynamic>.from(o.headers)
      ..['Authorization'] = 'Bearer $access';

    final opts = Options(
      method: o.method,
      headers: headers,
      responseType: o.responseType,
      contentType: o.contentType,
      followRedirects: o.followRedirects,
      sendTimeout: o.sendTimeout,
      receiveTimeout: o.receiveTimeout,
      validateStatus: o.validateStatus,
    );

    return dio.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: opts,
      cancelToken: o.cancelToken,
      onSendProgress: o.onSendProgress,
      onReceiveProgress: o.onReceiveProgress,
    );
  }
}
