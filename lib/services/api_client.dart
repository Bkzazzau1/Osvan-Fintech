// Osvan API client (Dio) aligned 1:1 to live backend routes (/api/...)
// Mobile hardening:
//  - Uses centralized SessionStore for tokens (web + mobile)
//  - Robust auth-path matching (works for absolute/relative URLs)
//  - Keeps X-Skip-Auth on auth endpoints to avoid stale Authorization
//  - Same headers/timeouts; HTTPS to fintech.osvan.africa

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:get/get.dart' hide Response;
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/store/session_store.dart';

/// ---- Centralized API paths (matched to server) -----------------------------
class ApiPaths {
  static const String base = 'https://fintech.osvan.africa';

  // Auth (Django SimpleJWT)
  static const String tokenLogin = '/api/token/login/'; // email or username
  static const String obtain = '/api/token/'; // legacy username
  static const String refresh = '/api/token/refresh/';

  // Health
  static const String health = '/api/health/';
  static const String profileMe = '/api/profile/me/';

  // User
  static const String userMe = '/api/user/me/';

  // Wallets
  static const String wallets = '/api/wallets/';
  static const String walletCreate = '/api/wallets/create/';

  // ── Virtual Accounts (stable contract)
  // Create + legacy status live on the SAME route (POST/GET):
  static const String virtualAccount = '/api/wallets/virtual-account/';
  // Preferred owner lookup:
  static const String virtualAccountMine = '/api/wallets/virtual-account/mine/';

  // Collections (info for country/method)
  static const String collectionDetails = '/api/wallets/collection/';

  // Crypto receive address list (if exposed)
  static const String cryptoWalletAddresses = '/api/wallets/crypto-addresses/';

  // Global add-money (test console)
  static const String addMoney = '/api/wallets/add-money/';

  // Fiat Transactions (wallet history)
  static const String transactions = '/api/transactions/';

  // Crypto (FE façade to your v1 crypto routes)
  static const String cryptoBalances = '/api/crypto/balances/';
  static const String cryptoAddress = '/api/crypto/address/';
  static const String cryptoTxs = '/api/crypto/transactions/';

  // Transfers
  static const String cryptoTransfer = '/api/transfer/crypto/';
  static const String transferEstimate = '/api/transfer/estimate/';
  static const String transferSend = '/api/transfer/send/';

  // --- Payouts (bank / mobile money) — kept for back-compat, prefer PayoutsApi
  static const String payoutCountries = '/api/payout/supported-countries/';
  static const String payoutRequirementsPrefix =
      '/api/payout/requirements/'; // + <country>/
  static const String payoutBanksPrefix =
      '/api/payout/banks/'; // + <country>/<currency>/
  static const String payoutBeneficiaries = '/api/payout/beneficiaries/';
  static const String payoutBeneficiariesList =
      '/api/payout/beneficiaries/list/';
  static const String payoutInit = '/api/payout/init/';
  static const String payoutFinalize = '/api/payout/finalize/';
  static const String payoutAttachDocPrefix =
      '/api/payout/attach-document/'; // + <transaction_id>/
}

/// Back-compat alias (static members aren’t inherited in Dart)
class _Api {
  // Auth
  static const tokenLogin = ApiPaths.tokenLogin;
  static const obtain = ApiPaths.obtain;
  static const refresh = ApiPaths.refresh;

  // Health
  static const health = ApiPaths.health;
  static const profileMe = ApiPaths.profileMe;

  // User
  static const userMe = ApiPaths.userMe;

  // Wallets
  static const wallets = ApiPaths.wallets;
  static const walletCreate = ApiPaths.walletCreate;

  // Virtual Accounts
  static const virtualAccount = ApiPaths.virtualAccount;
  static const virtualAccountMine = ApiPaths.virtualAccountMine;

  // Collections / misc
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

class ApiClient {
  final Dio _dio;
  final SessionStore _store;

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
    await SessionStore.init(); // ensure box is ready (safe on web/mobile)

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
      // ✅ Only 2xx is success. 4xx/5xx will throw DioException.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
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
          final hdr = await store.authHeader();
          if (hdr.isNotEmpty) {
            options.headers.addAll(hdr);
          }
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

        if (!isAuthPath(req.path) &&
            e.response?.statusCode == 401 &&
            !alreadyRetried) {
          final ok = await client._refreshTokens();
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

    return client;
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

  T _unwrap<T>(dynamic data) {
    if (data is Map) {
      if (data.containsKey('data')) return data['data'] as T;
      if (data.containsKey('results')) return data['results'] as T;
      if (data.containsKey('result')) return data['result'] as T;
    }
    return data as T;
  }

  Map<String, dynamic> _mapOrEmpty(dynamic data) =>
      (data is Map<String, dynamic>) ? data : <String, dynamic>{};

  /// Envelope normalizer → `{ ok, data, message }`
  Map<String, dynamic> _envelope(dynamic body) {
    final m = _mapOrEmpty(body);
    final data = m['data'] ?? m['result'] ?? body;
    final ok =
        (m['ok'] == true) || (m['status'] == true) || (m['success'] == true);
    final msg = (m['message'] ?? m['detail'] ?? 'done').toString();
    return {'ok': ok, 'data': data, 'message': msg};
  }

  /// Normalize provider/DB VA shapes (map or list) into a single flat FE map.
  Map<String, dynamic> _normalizeVAForFE(Map<String, dynamic> resp) {
    Map<String, dynamic> fromRecord(Map rec) {
      final rawStatus = (rec['status'] ?? 'READY').toString().toUpperCase();
      final status = (rawStatus == 'ACTIVE') ? 'READY' : rawStatus;
      return {
        'status': status,
        'account_name': rec['account_name'] ?? rec['accountName'],
        'account_number': rec['account_number'] ?? rec['accountNumber'],
        'bank_name': rec['bank_name'] ?? rec['bankName'] ?? rec['bank'],
        'bank_code': rec['bank_code'] ?? rec['bankCode'],
        'provider': rec['provider'] ?? 'local',
        'reference': rec['reference'],
        'currency': (rec['currency'] ?? 'NGN').toString().toUpperCase(),
      };
    }

    Map<String, dynamic> pickBestRecord(List items) {
      if (items.isEmpty) return <String, dynamic>{};
      try {
        final parsed = items
            .whereType<Map>()
            .map((e) => {
                  'raw': e,
                  'ts': DateTime.tryParse(
                          (e['created_at'] ?? e['createdAt'] ?? '')
                              .toString()) ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                })
            .toList();
        if (parsed.isNotEmpty) {
          parsed.sort((a, b) => (b['ts'] as DateTime)
              .compareTo(a['ts'] as DateTime)); // newest first
          return Map<String, dynamic>.from(parsed.first['raw'] as Map);
        }
      } catch (_) {}
      final first = items.first;
      return Map<String, dynamic>.from(
          first is Map ? first : <String, dynamic>{});
    }

    if (resp.containsKey('account_number') ||
        resp.containsKey('accountNumber')) {
      return fromRecord(resp);
    }

    if (resp.containsKey('result')) {
      final result = resp['result'];
      if (result is Map) {
        final data = result['data'];
        if (data is Map) {
          return fromRecord({
            ...data,
            'status': (data['status'] ?? 'active').toString().toUpperCase(),
            'provider': (resp['provider'] ?? 'brails').toString(),
          });
        }
        if (data is List && data.isNotEmpty) {
          final best = pickBestRecord(data);
          return fromRecord({
            ...best,
            'provider':
                (resp['provider'] ?? best['provider'] ?? 'local').toString(),
          });
        }
      }
    }

    if (resp.containsKey('data') && resp['data'] is List) {
      final list = resp['data'] as List;
      if (list.isNotEmpty) {
        final best = pickBestRecord(list);
        return fromRecord({
          ...best,
          'provider': resp['provider'] ?? best['provider'] ?? 'local',
        });
      }
    }

    return {'status': 'PENDING'};
  }

  Future<bool> _refreshTokens() async {
    if (_refreshing) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future;
        final hdr = await _store.authHeader();
        return hdr.containsKey('Authorization');
      } catch (_) {
        return false;
      }
    }

    _refreshing = true;
    try {
      final refresh = await _store.refresh;
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
          await _store.saveTokens(access: access); // keep existing refresh
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
    await _store.saveTokens(access: access, refresh: refresh);
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
    await _store.saveTokens(access: access, refresh: refresh);
  }

  Future<void> login(
      {required String username, required String password}) async {
    await loginSmart(username: username, password: password);
  }

  Future<void> logout() async => _store.clear();

  // ---------- user ----------
  Future<Map<String, dynamic>> getMe() async {
    try {
      final r = await _dio.get(_Api.profileMe);
      return Map<String, dynamic>.from(_unwrap(r.data));
    } catch (_) {
      final r = await _dio.get(_Api.userMe);
      return Map<String, dynamic>.from(r.data as Map);
    }
  }

  Future<Map<String, dynamic>> getProfileMe() async {
    final r = await _dio.get(_Api.profileMe);
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

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
    final r = await _dio.post(endpoint, data: {
      'amount': amount,
      'currency': currency,
    });
    return Map<String, dynamic>.from(_unwrap(r.data));
  }

  // Virtual Account (legacy GET status)
  Future<Map<String, dynamic>> getVirtualAccountStatus() async {
    final r = await _dio.get(
      _Api.virtualAccount,
      options: Options(
          sendTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5)),
    );
    return _normalizeVAForFE(Map<String, dynamic>.from(_unwrap(r.data)));
  }

  // Virtual Account (mine) — preferred
  Future<Map<String, dynamic>> getVirtualAccountMine() async {
    final r = await _dio.get(
      _Api.virtualAccountMine,
      options: Options(
          sendTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5)),
    );
    return _normalizeVAForFE(Map<String, dynamic>.from(_unwrap(r.data)));
  }

  /// Explicit create — POST /api/wallets/virtual-account/
  /// Accepts either `payload:` (new) or `data:` (old) for back-compat.
  /// Returns envelope: { ok, data, message, fe }
  Future<Map<String, dynamic>> createVirtualAccount({
    Map<String, dynamic>? payload, // NEW
    Map<String, dynamic>? data, // OLD call sites
  }) async {
    final body = payload ?? data ?? const <String, dynamic>{};

    final r = await _dio.post(
      _Api.virtualAccount, // POST /api/wallets/virtual-account/
      data: body,
      options: Options(
        sendTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 45),
      ),
    );

    final env = _envelope(r.data); // { ok, data, message }
    final fe = _normalizeVAForFE(
      Map<String, dynamic>.from(_unwrap(r.data)),
    );
    return {...env, 'fe': fe};
  }

  Future<Map<String, dynamic>?> waitForVAReady({
    Duration pollEvery = const Duration(seconds: 2),
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    final started = DateTime.now();
    Map<String, dynamic> last = {};
    while (DateTime.now().difference(started) < maxWait) {
      try {
        last = await getVirtualAccountMine(); // Prefer “mine” when available
      } catch (_) {
        last = await getVirtualAccountStatus(); // Fallback
      }
      final status =
          (last['status'] ?? last['state'] ?? 'READY').toString().toUpperCase();
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
      if (method != null) 'method': method,
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
      if (narration != null) 'narration': narration,
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

  /// Short-lived reverify ticket (e.g., to reveal card details).
  Future<Map<String, dynamic>> reverifyTicket() async {
    final res = await _dio.post(
      '${ApiPaths.base}/api/auth/reverify/',
      data: const {},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
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

Future<void> _forceLogoutToLogin() async {
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
