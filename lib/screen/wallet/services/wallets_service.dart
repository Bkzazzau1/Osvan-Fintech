// lib/screen/wallets/services/wallets_service.dart
// ignore_for_file: unintended_html_in_doc_comment

import 'package:osvan_app/services/api_client.dart';

import '../models/wallet.dart';

/// WalletsService — aligned to live Django/DRF endpoints
/// Confirmed/target endpoints:
/// - GET  `/api/wallets/`
/// - POST `/api/wallets/create/` { currency, label? }
/// - POST `/api/wallets/<id>/add_money/` { amount, currency }
/// - GET  `/api/wallets/virtual-account/`            (legacy status)
/// - POST `/api/wallets/virtual-account/`           (create)
/// - GET  `/api/wallets/virtual-account/mine/`      (preferred: current user's VA)
/// - GET  `/api/wallets/virtual-accounts/`          (list)
/// - GET  `/api/wallets/collection/` ?country=KE&method=bank|momo
/// - GET  `/api/transactions/?page=&page_size=&...`
/// - POST `/api/wallets/add-money/`                 (admin/test credit)
/// - GET  `/api/user/me/`                           (profile for prefill)
class WalletsService {
  WalletsService._();
  static final WalletsService instance = WalletsService._();

  /// ✅ Allow `WalletsService()` to work anywhere (returns the singleton).
  factory WalletsService() => instance;

  // Ensure ApiClient is ready (safe on hot restart and web/mobile)
  Future<ApiClient> _api() => ApiClient.ensureInitialized();

  // ---------------- User (for KYC prefill) ----------------

  /// Fetch current user profile for prefill (first/last/email/phone).
  /// Returns a Map (raw server shape).
  Future<Map<String, dynamic>> getCurrentUser() async {
    final api = await _api();
    final res = await api.getMe(); // expects GET /api/user/me/
    return Map<String, dynamic>.from(res);
  }

  // ---------------- Wallets ----------------

  /// Fetch all user wallets (typed to Wallet model)
  ///
  /// Handles:
  ///   - List:        `[ {...}, {...} ]`
  ///   - Paginated:   `{ results:[...], count, next, previous }`
  ///   - Envelope:    `{ data:[...] }`
  Future<List<Wallet>> fetchWallets() async {
    final api = await _api();
    final dynamic data = await api.listWallets(); // can be List or Map

    List<dynamic> rawList;

    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      if (data['results'] is List) {
        rawList = List<dynamic>.from(data['results'] as List);
      } else if (data['data'] is List) {
        rawList = List<dynamic>.from(data['data'] as List);
      } else {
        rawList = [];
      }
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map>()
        .map((e) => Wallet.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Create a new fiat wallet (server expects at least currency)
  /// POST `/api/wallets/create/`
  Future<Wallet> createWallet({
    required String currency, // e.g. 'NGN'
    String? label,
  }) async {
    final api = await _api();
    final res = await api.createWallet(currency: currency, label: label);
    return Wallet.fromJson(Map<String, dynamic>.from(res));
  }

  /// Add money to a specific wallet by ID.
  /// POST `/api/wallets/<id>/add_money/` { amount, currency }
  /// Returns the updated wallet object.
  Future<Wallet> addMoneyToWalletId({
    required int walletId,
    required String amount, // keep as string to avoid float issues
    required String currency, // e.g., 'NGN'
  }) async {
    final api = await _api();
    final res = await api.addMoneyToWalletId(
      walletId: walletId,
      amount: amount,
      currency: currency,
    );
    return Wallet.fromJson(Map<String, dynamic>.from(res));
  }

  // ---------------- Virtual Account (NGN) ----------------
  // IMPORTANT: We never auto-create a VA here. Controllers call create explicitly.

  /// Preferred: get current user's VA via `/api/wallets/virtual-account/mine/`
  /// Falls back to legacy GET `/api/wallets/virtual-account/` if 404/Not Implemented.
  Future<Map<String, dynamic>> getVirtualAccountMine() async {
    final api = await _api();
    try {
      final res = await api.getVirtualAccountMine(); // new endpoint
      return Map<String, dynamic>.from(res);
    } catch (_) {
      // Fallback to legacy status path
      final res = await api.getVirtualAccountStatus();
      return Map<String, dynamic>.from(res);
    }
  }

  /// Get NGN Virtual Account status/details (no creation).
  /// Uses `mine` first, then legacy.
  Future<Map<String, dynamic>> getVirtualAccountStatus() async {
    return getVirtualAccountMine();
  }

  /// Create NGN Virtual Account explicitly (user action).
  /// Accepts optional KYC payload; returns backend response.
  Future<Map<String, dynamic>> createVirtualAccount({
    Map<String, dynamic>? kyc,
  }) async {
    final api = await _api();
    final res = await api.createVirtualAccount(data: kyc);
    return Map<String, dynamic>.from(res);
  }

  /// Poll until VA becomes READY. Returns VA map when READY, `null` if timed out.
  /// Throws if status becomes FAILED.
  Future<Map<String, dynamic>?> waitForVAReady({
    Duration pollEvery = const Duration(seconds: 2),
    Duration maxWait = const Duration(seconds: 60),
  }) async {
    final api = await _api();
    return api.waitForVAReady(pollEvery: pollEvery, maxWait: maxWait);
  }

  // ---------------- Collections (KES/UGX) ----------------

  /// Collections rails (for Kenya/Uganda). UI should not call VA for these.
  /// Server path: `/api/wallets/collection/?country=KE&method=bank|momo`
  Future<Map<String, dynamic>> getCollectionDetails({
    required String country, // 'KE', 'UG', ...
    String? method, // 'momo' or 'bank'
  }) async {
    final api = await _api();
    final res =
        await api.getCollectionDetails(country: country, method: method);
    return Map<String, dynamic>.from(res);
  }

  // ---------------- Transactions (recent) ----------------

  /// Fetch recent fiat transactions (optionally filtered by currency code).
  /// Uses paginated `/api/transactions/` behind the scenes.
  ///
  /// Handles:
  ///   - List:      `[ {...}, {...} ]`
  ///   - Paginated: `{ results:[...], count, next, previous }`
  ///   - Envelope:  `{ data:[...] }`
  Future<List<Map<String, dynamic>>> fetchRecentTransactions({
    String? currency,
    int limit = 3,
  }) async {
    final api = await _api();
    final dynamic resp =
        await api.listFiatTransactions(currency: currency, limit: limit);

    List<dynamic> rawList;

    if (resp is List) {
      rawList = resp;
    } else if (resp is Map<String, dynamic>) {
      if (resp['results'] is List) {
        rawList = List<dynamic>.from(resp['results'] as List);
      } else if (resp['data'] is List) {
        rawList = List<dynamic>.from(resp['data'] as List);
      } else {
        rawList = [];
      }
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ---------------- Test/Admin Utilities ----------------

  /// Credit a wallet (admin/test). Server path: `/api/wallets/add-money/`
  /// Live backend expects `{ currency, amount, narration? }`
  Future<Map<String, dynamic>> creditWallet({
    required String currency, // e.g., 'NGN'
    required String amount, // keep as string
    String? narration,
  }) async {
    final api = await _api();
    final res = await api.creditWallet(
      currency: currency,
      amount: amount,
      narration: narration,
    );
    return Map<String, dynamic>.from(res);
  }

  /// Back-compat shim (avoid if possible).
  @Deprecated('Use addMoneyToWalletId(...) or creditWallet(...) instead.')
  Future<Map<String, dynamic>> creditWalletLegacy({
    required String walletId,
    required String amount,
    String reference = 'test-credit',
    String narration = 'Test credit from app',
  }) async {
    final api = await _api();
    final res = await api.creditWallet(
      currency: 'NGN',
      amount: amount,
      narration: narration,
    );
    return Map<String, dynamic>.from(res);
  }
}
