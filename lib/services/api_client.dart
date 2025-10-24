// Osvan API client (Dio) aligned 1:1 to live backend routes (/api/...)
// Mobile hardening:
//  - Initializes GetStorage automatically (first use) so Android/iOS don’t crash
//  - Robust auth-path matching (works even if caller uses absolute URLs)
//  - Keeps X-Skip-Auth on auth endpoints to avoid stale Authorization
//  - Same headers/timeouts; HTTPS to fintech.osvan.africa

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/config/env.dart';

/// ---- Centralized API paths (matched to server) -----------------------------
class ApiPaths {
  static const String base = 'https://fintech.osvan.africa';

  // Auth (Django SimpleJWT)
  static const String tokenLogin = '/api/token/login/'; // email or username
  static const String obtain = '/api/token/'; // legacy username
  static const String refresh = '/api/token/refresh/';

  // Health
  static const String health = '/api/health/';

  // Wallets
  static const String wallets = '/api/wallets/';
  static const String walletCreate = '/api/wallets/create/';
  static const String virtualAccount = '/api/wallets/virtual-account/';
  static const String collectionDetails = '/api/wallets/collection-details/';
  static const String cryptoWalletAddresses = '/api/wallets/crypto-addresses/';
  static const String addMoney = '/api/wallets/add-money/';

  // Fiat Transactions (wallet history)
  static const String transactions = '/api/transactions/';

  // Crypto
  static const String cryptoBalances = '/api/crypto/balances/';
  static const String cryptoAddress = '/api/crypto/address/';
  static const String cryptoTxs = '/api/crypto/transactions/';

  // Transfers
  static const String cryptoTransfer = '/api/transfer/crypto/';
  static const String transferEstimate = '/api/transfer/estimate/';
  static const String transferSend = '/api/transfer/send/';
}

/// Back-compat alias (static members aren’t inherited in Dart)
class _Api {
  // Auth
  static const tokenLogin = ApiPaths.tokenLogin;
  static const obtain = ApiPaths.obtain;
  static const refresh = ApiPaths.refresh;

  // Health
  static const health = ApiPaths.health;

  // Wallets
  static const wallets = ApiPaths.wallets;
  static const walletCreate = ApiPaths.walletCreate;
  static const virtualAccount = ApiPaths.virtualAccount;
  static const collectionDetails = ApiPaths.collectionDetails;
  static const addMoney = ApiPaths.addMoney;
  static const cryptoWalletAddresses = ApiPaths.cryptoWalletAddresses;

  // Fiat Transactions
  static const transactions = ApiPaths.transactions;

  // Crypto
  static const cryptoBalances = ApiPaths.cryptoBalances;
  static const cryptoAddress = ApiPaths.cryptoAddress;
  static const cryptoTxs = ApiPaths.cryptoTxs;

  // Transfers
  static const cryptoTransfer = ApiPaths.cryptoTransfer;
  static const transferEstimate = ApiPaths.transferEstimate;
  static const transferSend = ApiPaths.transferSend;
}

/// ---- Standardized token store ----------------------------------------------
class _TokenStore {
  final _secure = const FlutterSecureStorage();
  final _box = GetStorage();

  static bool _boxReady = false;
  static Future<void> ensureBoxReady() async {
    if (_boxReady) return;
    await GetStorage.init();
    _boxReady = true;
  }

  Future<String?> readAccess() async {
    await ensureBoxReady();
    final s = await _secure.read(key: 'access');
    if (s != null && s.isNotEmpty) return s;
    final boxAccess = _box.read<String>('access');
    if (boxAccess != null && boxAccess.isNotEmpty) return boxAccess;
    final legacy = _box.read<String>('token');
    return (legacy != null && legacy.isNotEmpty) ? legacy : null;
  }

  Future<String?> readRefresh() async {
    await ensureBoxReady();
    return await _secure.read(key: 'refresh') ?? _box.read<String>('refresh');
  }

  Future<void> writeBoth({required String access, String? refresh}) async {
    await ensureBoxReady();
    try {
      await _secure.write(key: 'access', value: access);
    } catch (_) {}
    await _box.write('access', access);
    await _box.write('token', access); // legacy alias

    if (refresh != null) {
      try {
        await _secure.write(key: 'refresh', value: refresh);
      } catch (_) {}
      await _box.write('refresh', refresh);
    }
  }

  Future<void> clear() async {
    await ensureBoxReady();
    try {
      await _secure.delete(key: 'access');
    } catch (_) {}
    try {
      await _secure.delete(key: 'refresh');
    } catch (_) {}
    await _box.remove('access');
    await _box.remove('refresh');
    await _box.remove('token');
  }
}

class ApiClient {
  final Dio _dio;
  final _TokenStore _store;

  bool _refreshing = false;
  final List<Completer<void>> _waiters = [];

  ApiClient._(this._dio, this._store);

  static ApiClient? _shared;

  static Future<ApiClient> ensureInitialized() async {
    _shared ??= await ApiClient.create();
    return _shared!;
  }

  static ApiClient get shared =>
      _shared ??
      (throw StateError(
          'ApiClient not initialized. Call ensureInitialized().'));

  Dio get dio => _dio;

  // Normalize Env.autoBaseUrl → trim '/' and strip trailing '/api'
  static String _normalizeRoot(String raw) {
    if (raw.isEmpty) return raw;
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('/api')) s = s.substring(0, s.length - 4);
    return s;
  }

  static Future<ApiClient> create() async {
    await _TokenStore.ensureBoxReady(); // <- mobile-safe
    final envBase = _normalizeRoot(Env.autoBaseUrl);
    final baseUrl =
        envBase.isNotEmpty ? envBase : _normalizeRoot(ApiPaths.base);

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      // Surface 4xx to app; Dio will still throw on transport errors
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

    final store = _TokenStore();
    final client = ApiClient._(dio, store);

    bool isAuthPath(String p) {
      // Works for relative or absolute path
      final path = Uri.parse(p).path; // strips scheme/host if present
      return path.endsWith(_Api.refresh) ||
          path.endsWith(_Api.obtain) ||
          path.endsWith(_Api.tokenLogin);
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.headers['X-Skip-Auth']?.toString() == '1';
        if (!skipAuth && !isAuthPath(options.path)) {
          final access = await store.readAccess();
          if (access?.isNotEmpty == true) {
            options.headers['Authorization'] = 'Bearer $access';
          }
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final req = e.requestOptions;
        final alreadyRetried = req.extra['__ret'] == true;

        if (!isAuthPath(req.path) &&
            e.response?.statusCode == 401 &&
            !alreadyRetried) {
          final ok = await client._refreshTokens();
          if (ok) {
            final newAccess = await store.readAccess();
            final clone = await dio.fetch(
              req.copyWith(
                headers: {
                  ...req.headers,
                  if (newAccess != null) 'Authorization': 'Bearer $newAccess',
                },
                extra: {...req.extra, '__ret': true},
              ),
            );
            return handler.resolve(clone);
          }
        }
        handler.next(e);
      },
    ));

    return client;
  }

  T _unwrap<T>(dynamic data) {
    if (data is Map) {
      if (data.containsKey('data')) return data['data'] as T;
      if (data.containsKey('results')) return data['results'] as T;
    }
    return data as T;
  }

  Map<String, dynamic> _mapOrEmpty(dynamic data) =>
      (data is Map<String, dynamic>) ? data : <String, dynamic>{};

  Future<bool> _refreshTokens() async {
    if (_refreshing) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future;
        return (await _store.readAccess())?.isNotEmpty == true;
      } catch (_) {
        return false;
      }
    }

    _refreshing = true;
    try {
      final refresh = await _store.readRefresh();
      if (refresh == null || refresh.isEmpty) return false;

      try {
        final r = await _dio.post(
          _Api.refresh,
          data: {'refresh': refresh},
          options: Options(
            headers: {'X-Skip-Auth': '1'},
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final m = _mapOrEmpty(r.data);
        final access = (m['access'] as String?) ?? '';
        if (access.isNotEmpty) {
          await _store.writeBoth(access: access);
          _flushWaiters();
          return true;
        }
      } catch (_) {}

      _failWaiters();
      await _store.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  void _flushWaiters() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  void _failWaiters() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.completeError(StateError('refresh failed'));
    }
    _waiters.clear();
  }

  // ---------- health ----------
  Future<bool> ping() async {
    try {
      final r = await _dio.get(
        _Api.health,
        options: Options(headers: {'X-Skip-Auth': '1'}),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- auth ----------
  /// Email-first login against /api/token/login/
  Future<void> loginEmail({
    required String email,
    required String password,
  }) async {
    final r = await _dio.post(
      _Api.tokenLogin,
      data: {'email': email.trim(), 'password': password},
      options: Options(headers: {'X-Skip-Auth': '1'}),
    );
    final body = _mapOrEmpty(r.data);
    final access = (body['access'] as String?) ?? '';
    final refresh = body['refresh'] as String?;
    if (access.isEmpty) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'No access token in response',
        type: DioExceptionType.badResponse,
      );
    }
    await _store.writeBoth(access: access, refresh: refresh);
  }

  /// Smart login — prefer email; else username.
  Future<void> loginSmart({
    String? email,
    String? username,
    required String password,
  }) async {
    final payload = <String, dynamic>{'password': password};
    if ((email ?? '').isNotEmpty) {
      payload['email'] = email!.trim();
    } else if ((username ?? '').isNotEmpty) {
      payload['username'] = username;
    } else {
      throw ArgumentError('Provide email or username');
    }

    final r = await _dio.post(
      _Api.tokenLogin,
      data: payload,
      options: Options(headers: {'X-Skip-Auth': '1'}),
    );
    final body = _mapOrEmpty(r.data);
    final access = (body['access'] as String?) ?? '';
    final refresh = body['refresh'] as String?;
    if (access.isEmpty) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'No access token in response',
        type: DioExceptionType.badResponse,
      );
    }
    await _store.writeBoth(access: access, refresh: refresh);
  }

  Future<void> login(
      {required String username, required String password}) async {
    await loginSmart(username: username, password: password);
  }

  Future<void> logout() async => _store.clear();

  // ---------- wallets ----------
  Future<List<dynamic>> listWallets() async {
    final r = await _dio.get(_Api.wallets);
    return List<dynamic>.from(_unwrap(r.data) as List);
  }

  Future<Map<String, dynamic>> createWallet({
    required String currency, // e.g., "NGN"
    String? label,
  }) async {
    final r = await _dio.post(_Api.walletCreate, data: {
      'currency': currency,
      if (label != null) 'label': label,
    });
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  /// Add money to a specific wallet by ID (`/api/wallets/<id>/add_money/`)
  Future<Map<String, dynamic>> addMoneyToWalletId({
    required int walletId,
    required String amount,
    required String currency,
  }) async {
    final endpoint = '${_Api.wallets}$walletId/add_money/';
    final r = await _dio
        .post(endpoint, data: {'amount': amount, 'currency': currency});
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  // Virtual Account
  Future<Map<String, dynamic>> getVirtualAccountStatus() async {
    final r = await _dio.get(
      _Api.virtualAccount,
      options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5)),
    );
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  Future<Map<String, dynamic>> createVirtualAccount(
      {Map<String, dynamic>? data}) async {
    final r = await _dio.post(
      _Api.virtualAccount,
      data: data ?? const <String, dynamic>{},
      options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 45)),
    );
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  Future<Map<String, dynamic>?> waitForVAReady({
    Duration pollEvery = const Duration(seconds: 2),
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    final started = DateTime.now();
    Map<String, dynamic> last = {};
    while (DateTime.now().difference(started) < maxWait) {
      last = await getVirtualAccountStatus();
      final status = (last['status'] ?? 'READY').toString().toUpperCase();
      if (status == 'READY') return last;
      if (status == 'FAILED') {
        throw DioException(
          requestOptions: RequestOptions(path: _Api.virtualAccount),
          message:
              last['error']?.toString() ?? 'Virtual account creation failed',
          type: DioExceptionType.badResponse,
        );
      }
      await Future.delayed(pollEvery);
    }
    return null;
  }

  Future<Map<String, dynamic>> getCollectionDetails({
    required String country, // e.g., 'NG'
    String? method, // 'momo' | 'bank'
  }) async {
    final q = <String, dynamic>{
      'country': country,
      if (method != null) 'method': method
    };
    final r = await _dio.get(_Api.collectionDetails, queryParameters: q);
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  /// Credit wallet (Test Console) — /api/wallets/add-money/
  Future<Map<String, dynamic>> creditWallet({
    required String currency, // e.g., 'NGN'
    required String amount, // string to avoid float issues
    String? narration,
  }) async {
    final payload = {
      'currency': currency,
      'amount': amount,
      if (narration != null) 'narration': narration
    };
    final r = await _dio.post(_Api.addMoney, data: payload);
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  /// ---- Fiat transactions (wallet activity) ----
  Future<List<dynamic>> listFiatTransactions({
    String? currency,
    int? limit,
    int? pageSize,
    int? page,
  }) async {
    final q = <String, dynamic>{
      if (currency != null && currency.isNotEmpty) 'currency': currency,
      if (limit != null) 'limit': limit,
      if (pageSize != null) 'page_size': pageSize,
      if (page != null) 'page': page,
    };
    final r = await _dio.get(_Api.transactions, queryParameters: q);
    return List<dynamic>.from(_unwrap(r.data) as List);
  }

  Future<List<dynamic>> listCryptoReceiveAddresses() async {
    final r = await _dio.get(_Api.cryptoWalletAddresses);
    return List<dynamic>.from(_unwrap(r.data) as List);
  }

  // ---------- crypto ----------
  Future<List<dynamic>> listBalances() async {
    final r = await _dio.get(_Api.cryptoBalances);
    return List<dynamic>.from(_unwrap(r.data) as List);
  }

  Future<Map<String, dynamic>> generateAddress({
    required String ticker,
    required String network,
  }) async {
    final r = await _dio.post(_Api.cryptoAddress, data: {
      'ticker': ticker.toUpperCase(),
      'network': network.toUpperCase(),
    });
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  Future<List<dynamic>> listTransactions({
    String? ticker,
    String? network,
    String? status,
    String? type,
    int? pageSize,
    int? page,
  }) async {
    final q = <String, dynamic>{
      if (ticker != null) 'ticker': ticker.toUpperCase(),
      if (network != null) 'network': network.toUpperCase(),
      if (status != null) 'status': status,
      if (type != null) 'type': type,
      if (pageSize != null) 'page_size': pageSize,
      if (page != null) 'page': page,
    };
    final r = await _dio.get(_Api.cryptoTxs, queryParameters: q);
    return List<dynamic>.from(_unwrap(r.data) as List);
  }

  // ---------- transfers ----------
  Future<Map<String, dynamic>> transferCrypto({
    required String ticker,
    required String network,
    required String toAddress,
    required String amount,
    String? idempotencyKey,
  }) async {
    final key = (idempotencyKey?.isNotEmpty == true)
        ? idempotencyKey!
        : DateTime.now().microsecondsSinceEpoch.toString();

    final payload = {
      'ticker': ticker.toUpperCase(),
      'network': network.toUpperCase(),
      'to_address': toAddress,
      'amount': amount,
      'idempotency_key': key, // header + body
      'idem': key,
    };

    final r = await _postWithRetry(
      _Api.cryptoTransfer,
      data: payload,
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  Future<Map<String, dynamic>> estimateTransfer(
      {required Map<String, dynamic> data}) async {
    final r = await _dio.post(_Api.transferEstimate, data: data);
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  Future<Map<String, dynamic>> sendTransfer(
      {required Map<String, dynamic> data}) async {
    final r = await _dio.post(_Api.transferSend, data: data);
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  // ---------- retry helper ----------
  Future<Response<dynamic>> _postWithRetry(
    String path, {
    required Map<String, dynamic> data,
    required Options options,
    int attempts = 3,
    Duration baseDelay = const Duration(milliseconds: 300),
  }) async {
    DioException? last;
    for (var i = 0; i < attempts; i++) {
      try {
        return await _dio.post(path, data: data, options: options);
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
}
