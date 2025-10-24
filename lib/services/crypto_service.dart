import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Backend-facing service (Flutter → Django/DRF).
/// Base URL must be your API v1 root, e.g. https://fintech.osvan.africa/api/v1
class CryptoService {
  final String baseUrl;
  final Dio _dio;
  final _uuid = const Uuid();

  /// Optional provider that returns the bare JWT (no "Bearer ").
  /// If not supplied, _getToken() is used (you can wire AuthService there).
  final Future<String?> Function()? tokenProvider;

  CryptoService({
    required this.baseUrl,
    this.tokenProvider,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    // Single interceptor (no per-call stacking)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach auth once per request
          final token = await _fetchToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // Optional: short retry for transient errors
          if (_shouldRetry(e)) {
            try {
              final retryResponse = await _retry(e.requestOptions);
              handler.resolve(retryResponse);
              return;
            } catch (_) {
              // fall through to normalize error
            }
          }
          handler.reject(_normalizeDioError(e));
        },
      ),
    );
  }

  // ====== Public API ======

  /// GET /crypto/coins
  Future<List<Map<String, dynamic>>> listCoins() async {
    final r = await _dio.get('/crypto/coins');
    if (r.data is List) return (r.data as List).cast<Map<String, dynamic>>();
    throw DioException(
      requestOptions: r.requestOptions,
      error: {'message': 'Unexpected /crypto/coins'},
      response: r,
    );
  }

  /// GET /crypto/address?coin=USDT&chain=TRON
  Future<Map<String, dynamic>> getAddress({
    required String coin,
    required String chain,
  }) async {
    final r = await _dio.get(
      '/crypto/address',
      queryParameters: {'coin': coin, 'chain': chain},
    );
    return Map<String, dynamic>.from(r.data);
  }

  /// POST /crypto/send/quote
  /// Body: {coin, chain, amount, to}
  Future<Map<String, dynamic>> quote({
    required String coin,
    required String chain,
    required String amount, // decimal as string
    required String to,
  }) async {
    final r = await _dio.post(
      '/crypto/send/quote',
      data: {'coin': coin, 'chain': chain, 'amount': amount, 'to': to},
    );
    return Map<String, dynamic>.from(r.data);
  }

  /// POST /crypto/send/confirm
  /// Body: {quote_id, pin_or_bio, idempotency_key}
  Future<Map<String, dynamic>> send({
    required String quoteId,
    required String pinOrBio,
  }) async {
    final idem = _uuid.v4();
    final r = await _dio.post(
      '/crypto/send/confirm',
      data: {
        'quote_id': quoteId,
        'pin_or_bio': pinOrBio,
        'idempotency_key': idem,
      },
      options: Options(headers: {'Idempotency-Key': idem}),
    );
    return Map<String, dynamic>.from(r.data);
  }

  /// GET /crypto/transactions?coin=USDT   (add pagination server-side later)
  Future<List<Map<String, dynamic>>> history({required String coin}) async {
    final r = await _dio.get(
      '/crypto/transactions',
      queryParameters: {'coin': coin},
    );
    if (r.data is List) return (r.data as List).cast<Map<String, dynamic>>();
    throw DioException(
      requestOptions: r.requestOptions,
      error: {'message': 'Unexpected /crypto/transactions'},
      response: r,
    );
  }

  /// (Optional) GET /wallets/crypto-balances
  /// Expected: [{coin:"USDT", chain:"TRON", balance:"12.34"}]
  Future<List<Map<String, dynamic>>> balances() async {
    final r = await _dio.get('/wallets/crypto-balances');
    if (r.data is List) return (r.data as List).cast<Map<String, dynamic>>();
    return const [];
  }

  // ====== Internals ======

  Future<String?> _fetchToken() async {
    if (tokenProvider != null) {
      return tokenProvider!.call();
    }
    return _getToken(); // fallback
  }

  /// Wire your AuthService here if you prefer not to pass tokenProvider.
  Future<String?> _getToken() async {
    // Example:
    // return await AuthService.getToken();
    return null;
  }

  bool _shouldRetry(DioException e) {
    // Only idempotent GETs and safe POSTs (our confirm has idempotency key)
    final method = e.requestOptions.method.toUpperCase();
    final isSafe = method == 'GET' ||
        (method == 'POST' && e.requestOptions.path.endsWith('/confirm'));
    final status = e.response?.statusCode ?? 0;
    final transient =
        status == 429 || status == 502 || status == 503 || status == 504;
    final tries = (e.requestOptions.extra['retry_count'] as int?) ?? 0;
    return isSafe && transient && tries < 2;
  }

  Future<Response<dynamic>> _retry(RequestOptions original) async {
    final tries = (original.extra['retry_count'] as int?) ?? 0;
    final next = tries + 1;

    // Exponential backoff with jitter (200ms, 400ms)
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
    // (Auth header will be reattached by the interceptor.)
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
