import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:get/get.dart' hide Response;
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/store/session_store.dart';

/// CoreClient provides:
/// - a shared Dio instance (with auth interceptor & refresh)
/// - normalized baseUrl (supports Env.autoBaseUrl)
/// - small helpers you can reuse across modules
class CoreClient {
  CoreClient._(this.dio);

  static CoreClient? _singleton;
  final Dio dio;

  static CoreClient get I {
    if (_singleton == null) {
      throw StateError(
          'CoreClient not initialized. Call CoreClient.ensure() first.');
    }
    return _singleton!;
  }

  static String _normalizeRoot(String raw) {
    if (raw.isEmpty) return raw;
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('/api')) s = s.substring(0, s.length - 4);
    return s;
  }

  static bool _isAuthPath(String path) {
    // Keep paths local here to avoid circular imports
    return path.endsWith('/api/token/login/') ||
        path.endsWith('/api/token/') ||
        path.endsWith('/api/token/refresh/');
  }

  static Future<CoreClient> ensure({
    Duration connectTimeout = const Duration(seconds: 20),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) async {
    if (_singleton != null) return _singleton!;

    await SessionStore.init();

    final envBase = _normalizeRoot(Env.autoBaseUrl);
    final baseUrl =
        envBase.isNotEmpty ? envBase : 'https://fintech.osvan.africa';

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (code) => code != null && code < 500,
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestBody: true,
        requestHeader: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    final store = SessionStore.instance;

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.headers['X-Skip-Auth']?.toString() == '1';
        if (!skipAuth && !_isAuthPath(Uri.parse(options.path).path)) {
          final hdr = await store.authHeader();
          if (hdr.isNotEmpty) options.headers.addAll(hdr);
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        if (_isAuthExpiredResponse(response)) {
          await _forceLogoutToLogin();
          return;
        }
        handler.next(response);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        final alreadyRetried = req.extra['__ret'] == true;
        if (!_isAuthPath(Uri.parse(req.path).path) &&
            e.response?.statusCode == 401 &&
            !alreadyRetried) {
          final ok = await _refreshTokens(dio, store);
          if (ok) {
            final newHdr = await store.authHeader();
            final clone = await dio.fetch(
              req.copyWith(
                headers: {...req.headers, ...newHdr},
                extra: {...req.extra, '__ret': true},
              ),
            );
            return handler.resolve(clone);
          }
          await _forceLogoutToLogin();
          return;
        }
        if (e.response?.statusCode == 401) {
          await _forceLogoutToLogin();
        }
        handler.next(e);
      },
    ));

    return _singleton = CoreClient._(dio);
  }

  static bool _isAuthExpiredResponse(Response res) {
    final code = res.statusCode ?? 0;
    if (code != 401 && code != 403) return false;
    final data = res.data;
    if (data is Map) {
      final msg =
          '${data['detail'] ?? data['message'] ?? data['error'] ?? ''}'.toLowerCase();
      final codeStr = '${data['code'] ?? ''}'.toLowerCase();
      if (msg.contains('token') ||
          msg.contains('credential') ||
          msg.contains('expired') ||
          codeStr.contains('token') ||
          codeStr.contains('expired')) {
        return true;
      }
    }
    return true; // treat unknown 401/403 as expired
  }

  static Future<bool> _refreshTokens(Dio dio, SessionStore store) async {
    final refresh = await store.refresh;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final r = await dio.post(
        '/api/token/refresh/',
        data: {'refresh': refresh},
        options: Options(headers: {'X-Skip-Auth': '1'}),
      );
      final access = (r.data is Map) ? (r.data['access'] as String? ?? '') : '';
      if (access.isNotEmpty) {
        await store.saveTokens(access: access);
        return true;
      }
    } catch (_) {}
    await store.clear();
    return false;
  }

  // ─────────────────────────── Normalizers ───────────────────────────
  /// Tolerant unwrap:
  /// - If payload is List → return List
  /// - If payload is Map and has `data`/`results`/`result` → return that value
  /// - Otherwise returns the original payload
  ///
  /// NOTE: This returns `dynamic` on purpose to avoid bad casts when the
  /// backend flips between Map and List. Callers should type-check.
  dynamic unwrap(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      if (data.containsKey('data')) return data['data'];
      if (data.containsKey('results')) return data['results'];
      if (data.containsKey('result')) return data['result'];
      return data;
    }

    return data;
  }

  Map<String, dynamic> mapOrEmpty(dynamic data) =>
      (data is Map<String, dynamic>) ? data : <String, dynamic>{};

  Map<String, dynamic> envelope(dynamic body) {
    final m = mapOrEmpty(body);
    final data = m['data'] ?? m['result'] ?? body;
    final ok =
        (m['ok'] == true) || (m['status'] == true) || (m['success'] == true);
    final msg = (m['message'] ?? m['detail'] ?? 'done').toString();
    return {'ok': ok, 'data': data, 'message': msg};
  }

  // ─────────────────────────── Utilities ───────────────────────────
  Future<Response<dynamic>> postWithRetry(
    String path, {
    required Map<String, dynamic> data,
    Options? options,
    int attempts = 3,
    Duration baseDelay = const Duration(milliseconds: 300),
  }) async {
    DioException? last;
    for (var i = 0; i < attempts; i++) {
      try {
        return await dio.post(path, data: data, options: options);
      } on DioException catch (e) {
        last = e;
        final code = e.response?.statusCode ?? 0;
        final transient = code == 429 || (code >= 500 && code < 600);
        if (!transient || i == attempts - 1) rethrow;
        final jitterMs = Random().nextInt(150);
        final mult = 1 << i; // 1,2,4
        final wait =
            Duration(milliseconds: baseDelay.inMilliseconds * mult + jitterMs);
        await Future.delayed(wait);
      }
    }
    throw last!;
  }

  // ─────────────────────────── Conversion helpers (added) ───────────────────────────
  /// POST /api/v1/convert/quote
  /// Example:
  ///   await CoreClient.I.convertQuote(from: 'USD', to: 'NGN', amount: '3.00');
  Future<Map<String, dynamic>> convertQuote({
    required String from,
    required String to,
    String? network,
    required String amount,
    String path = '/api/v1/convert/quote',
  }) async {
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      'amount': amount,
      if (network != null && network.isNotEmpty) 'network': network,
    };
    final res = await dio.post(path, data: payload);
    return mapOrEmpty(res.data);
  }

  /// POST /api/v1/convert/confirm
  /// Example:
  ///   await CoreClient.I.convertConfirm(
  ///     from: 'USD', to: 'USDT', amount: '2.00', network: 'TRON',
  ///     idempotencyKey: 'usd-usdt-1', debug: true,
  ///   );
  Future<Map<String, dynamic>> convertConfirm({
    required String from,
    required String to,
    String? network,
    required String amount,
    String? idempotencyKey,
    bool debug = false,
    String path = '/api/v1/convert/confirm',
  }) async {
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      'amount': amount,
      if (network != null && network.isNotEmpty) 'network': network,
    };

    final headers = <String, dynamic>{};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    if (debug) headers['X-Debug'] = '1';

    final res = await dio.post(
      path,
      data: payload,
      options: Options(headers: headers.isEmpty ? null : headers),
    );
    return mapOrEmpty(res.data);
  }
}

Future<void> _forceLogoutToLogin() async {
  // Prevent multiple simultaneous redirects/snackbars.
  if (_forcingLogout) return;
  _forcingLogout = true;
  try {
    await SessionStore.instance.clear();
  } catch (_) {}
  try {
    if (Get.currentRoute != '/login') {
      Get.snackbar(
        'Session expired',
        'Please sign in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAllNamed('/login');
    }
  } finally {
    _forcingLogout = false;
  }
}

bool _forcingLogout = false;
