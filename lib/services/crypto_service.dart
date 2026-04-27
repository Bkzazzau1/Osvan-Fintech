// lib/services/crypto_service.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Backend-facing service (Flutter → Django/DRF).
/// Pass baseUrl like:
///   - https://fintech.osvan.africa/api        (will be upgraded to /api/v1)
///   - https://fintech.osvan.africa/api/v1     (already correct)
/// All endpoints here are relative to that base (no extra /v1 in paths).
class CryptoService {
  final String baseUrl; // normalized to end with /api/v1
  final Dio _dio;
  final _uuid = const Uuid();

  /// Optional provider that returns the bare JWT (no "Bearer ").
  /// If not supplied, _getToken() is used (wire your AuthService there).
  final Future<String?> Function()? tokenProvider;

  static String _ensureV1(String url) {
    // remove trailing slashes
    final trimmed = url.replaceFirst(RegExp(r'/+$'), '');

    // already correct
    if (trimmed.endsWith('/api/v1')) return trimmed;

    // upgrade /api -> /api/v1
    if (trimmed.endsWith('/api')) return '$trimmed/v1';

    // if it already contains /api/v1 anywhere (rare), keep it
    if (RegExp(r'/api/v1($|/)').hasMatch(trimmed)) return trimmed;

    // otherwise force /api/v1 (covers bare host or custom path)
    return '$trimmed/api/v1';
  }


  CryptoService({
    required String baseUrl,
    this.tokenProvider,
    Dio? dio,
  })  : baseUrl = _ensureV1(baseUrl),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _ensureV1(baseUrl),
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                // Let 4xx flow to our error normalizer
                validateStatus: (code) => code != null && code < 500,
              ),
            ) {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _fetchToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('[Crypto] ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (_shouldRetry(e)) {
            try {
              final retryResponse = await _retry(e.requestOptions);
              handler.resolve(retryResponse);
              return;
            } catch (_) {
              // fall through
            }
          }
          handler.reject(_normalizeDioError(e));
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Routes (relative to baseUrl)
  // With baseUrl == https://fintech.osvan.africa/api/v1
  // these resolve to /api/v1/crypto/...
  // ─────────────────────────────────────────────────────────────
  static const _coinsPath = '/crypto/coins/';
  static const _addrPath = '/crypto/address/';
  static const _quotePath = '/crypto/send/quote/';
  static const _confirmPath = '/crypto/send/confirm/';
  static const _txsPath = '/crypto/transactions/';
  // Optional balances endpoint (present in your v1 crypto bundle)
  static const _balancesPath = '/wallets/crypto-balances/';
  static const _ensurePath = '/crypto/wallets/ensure/';

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  /// Unwraps common DRF envelopes: { ok|status|success, data|result }.
  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
      if (body.containsKey('result')) return body['result'];
    }
    return body;
  }

  /// Best-effort coercion of any body into a JSON map.
  Map<String, dynamic> _asJsonMap(dynamic data, {String pathForError = ''}) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final s = data.trim();

      // If it looks like HTML, surface a clean error
      final lower = s.toLowerCase();
      if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
        throw DioException(
          requestOptions: RequestOptions(path: pathForError),
          type: DioExceptionType.badResponse,
          error: {'message': 'Invalid response (HTML) from $pathForError'},
        );
      }

      // If it looks like JSON, try to decode
      if ((s.startsWith('{') && s.endsWith('}')) ||
          (s.startsWith('"') && s.endsWith('"'))) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
          if (decoded is String) return {'address': decoded};
        } catch (_) {
          // fall through to plain text handling
        }
      }

      // Otherwise treat as plain address string
      return {'address': s};
    }
    // Fallback
    return {'message': data?.toString() ?? ''};
  }

  // ─────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────

  /// GET /crypto/coins/
  Future<List<Map<String, dynamic>>> listCoins() async {
    final r = await _dio.get(_coinsPath);
    final payload = _unwrap(r.data);
    if (payload is List) {
      return payload.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      error: {'message': 'Unexpected /crypto/coins/ response'},
      type: DioExceptionType.badResponse,
    );
  }

  /// POST /crypto/wallets/ensure/ (idempotent)
  Future<void> ensureWallets() async {
    try {
      await _dio.post(_ensurePath);
    } catch (_) {
      // non-fatal
    }
  }

  /// GET /crypto/address/?coin=USDT&chain=TRON
  Future<Map<String, dynamic>> getAddress({
    required String coin,
    required String chain,
  }) async {
    final r = await _dio.get(
      _addrPath,
      queryParameters: {'coin': coin, 'chain': chain},
    );

    // If the server sent a plain string or an envelope, normalize it.
    final unwrapped = _unwrap(r.data);
    final map = _asJsonMap(unwrapped, pathForError: _addrPath);

    // Normalize common keys (address/addr, tag/memo, provider/source)
    return {
      'address': (map['address'] ?? map['addr'] ?? '').toString(),
      'tag': map['tag']?.toString() ?? map['memo']?.toString(),
      'provider': (map['provider'] ?? map['source'] ?? 'Brails').toString(),
    };
  }

  /// POST /crypto/send/quote/
  /// Body: {coin, chain, amount, to}
  Future<Map<String, dynamic>> quote({
    required String coin,
    required String chain,
    required String amount, // decimal as string
    required String to,
  }) async {
    final r = await _dio.post(
      _quotePath,
      data: {'coin': coin, 'chain': chain, 'amount': amount, 'to': to},
    );
    return Map<String, dynamic>.from(_unwrap(r.data) as Map);
  }

  /// POST /crypto/send/confirm/
  /// Body: {quote_id, pin_or_bio, idempotency_key}
  Future<Map<String, dynamic>> send({
    required String quoteId,
    required String pinOrBio,
  }) async {
    final idem = _uuid.v4();
    final r = await _dio.post(
      _confirmPath,
      data: {
        'quote_id': quoteId,
        'pin_or_bio': pinOrBio,
        'idempotency_key': idem,
      },
      options: Options(headers: {'Idempotency-Key': idem}),
    );
    return Map<String, dynamic>.from(_unwrap(r.data) as Map);
  }

  /// GET /crypto/transactions/?coin=USDT&network=TRON&status=CONFIRMED&type=deposit&page_size=20&page=1
  /// All params are optional; pass only what you need.
  Future<List<Map<String, dynamic>>> history({
    String? coin, // e.g., 'USDT'
    String? network, // e.g., 'TRON'
    String? status, // 'PENDING' | 'CONFIRMED' | 'FAILED' | 'ON_HOLD'
    String? type, // 'deposit' | 'withdraw'
    int? pageSize, // maps to page_size
    int? page,
  }) async {
    final q = <String, dynamic>{
      if (coin != null && coin.isNotEmpty) 'coin': coin,
      if (network != null && network.isNotEmpty) 'network': network,
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
      if (pageSize != null) 'page_size': pageSize,
      if (page != null) 'page': page,
    };

    final r = await _dio.get(_txsPath, queryParameters: q);
    final payload = _unwrap(r.data);
    if (payload is List) {
      return payload.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      error: {'message': 'Unexpected /crypto/transactions/ response'},
      type: DioExceptionType.badResponse,
    );
  }

  /// Optional: GET /wallets/crypto-balances/
  /// Expected: [{coin:"USDT", chain:"TRON", balance:"12.34"}]
  Future<List<Map<String, dynamic>>> balances() async {
    try {
      final r = await _dio.get(_balancesPath);
      final payload = _unwrap(r.data);
      if (payload is List) {
        return payload.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      // Treat non-list payloads as empty (soft fallback)
      return const [];
    } on DioException catch (e) {
      // Gracefully ignore if not implemented (404) or unauthorized in early dev
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 401) return const [];
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────

  Future<String?> _fetchToken() async {
    if (tokenProvider != null) return tokenProvider!.call();
    return _getToken(); // fallback
  }

  /// Wire your AuthService here if you prefer not to pass tokenProvider.
  Future<String?> _getToken() async {
    // Example:
    // return await AuthService.getToken();
    return null;
  }

  bool _shouldRetry(DioException e) {
    final method = e.requestOptions.method.toUpperCase();
    final isSafe = method == 'GET' ||
        (method == 'POST' && e.requestOptions.path.endsWith('/confirm/'));
    final status = e.response?.statusCode ?? 0;
    final transient = status == 0 ||
        status == 429 ||
        status == 502 ||
        status == 503 ||
        status == 504;
    final tries = (e.requestOptions.extra['retry_count'] as int?) ?? 0;
    return isSafe && transient && tries < 2;
  }

  Future<Response<dynamic>> _retry(RequestOptions original) async {
    final tries = (original.extra['retry_count'] as int?) ?? 0;
    final next = tries + 1;

    // Exponential backoff with jitter (≈200ms, 400ms)
    final base = 200 * math.pow(2, tries);
    final jitter = math.Random().nextInt(120);
    await Future.delayed(Duration(milliseconds: (base + jitter).toInt()));

    final opts = Options(
      method: original.method,
      headers: original.headers,
      responseType: original.responseType,
      contentType: original.contentType,
      followRedirects: original.followRedirects,
      listFormat: original.listFormat,
      sendTimeout: original.sendTimeout,
      receiveTimeout: original.receiveTimeout,
      validateStatus: original.validateStatus,
      extra: Map<String, dynamic>.from(original.extra)..['retry_count'] = next,
    );

    return _dio.request<dynamic>(
      original.path,
      data: original.data,
      queryParameters: original.queryParameters,
      options: opts,
      cancelToken: original.cancelToken,
      onReceiveProgress: original.onReceiveProgress,
      onSendProgress: original.onSendProgress,
    );
  }

  DioException _normalizeDioError(DioException e) {
    final data = e.response?.data;
    String? code;
    String message = 'Request failed';

    if (data is Map<String, dynamic>) {
      code = data['code']?.toString();
      message = data['detail']?.toString() ??
          data['message']?.toString() ??
          jsonEncode(data);
    } else if (data is String) {
      message = data;
    }

    return DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      type: e.type,
      error: {'code': code, 'message': message},
    );
  }
}
