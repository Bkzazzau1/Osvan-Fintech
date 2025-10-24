// lib/features/wallets/services/wallets_service.dart
// ignore_for_file: unintended_html_in_doc_comment

import 'package:osvan_app/services/api_client.dart';

import '../models/wallet.dart';

/// WalletsService — aligned to live Django/DRF endpoints
/// Backends (confirmed live):
/// - GET  `/api/wallets/`
/// - POST `/api/wallets/create/` { currency, label? }
/// - POST `/api/wallets/<id>/add_money/` { amount, currency }
/// - GET  `/api/wallets/virtual-account/`        (status)
/// - POST `/api/wallets/virtual-account/`        (create)
/// - GET  `/api/wallets/collection-details/?country=NG&method=bank|momo`
/// - GET  `/api/transactions/?page=&page_size=&...` (used by recent fetch)
class WalletsService {
  WalletsService();
  WalletsService._();
  static final instance = WalletsService._();

  // Ensure ApiClient is ready (safe on hot restart and web/mobile)
  Future<ApiClient> _api() => ApiClient.ensureInitialized();

  // ---------------- Wallets ----------------

  /// Fetch all user wallets (typed to Wallet model)
  Future<List<Wallet>> fetchWallets() async {
    final api = await _api();
    final data = await api.listWallets(); // expects List<Map>
    return data
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
  /// POST `/api/wallets/<id>/add_money/`  body: `{ amount: '1000', currency: 'NGN' }`
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
    ); // returns updated wallet map
    return Wallet.fromJson(Map<String, dynamic>.from(res));
  }

  // ---------------- Virtual Account (NGN) ----------------
  // IMPORTANT: We never auto-create a VA here. Controllers call create explicitly.

  /// Get NGN Virtual Account status/details (no creation).
  /// Backend returns at least `{ status: 'PENDING'|'CREATING'|'READY'|'FAILED' }`.
  Future<Map<String, dynamic>> getVirtualAccountStatus() async {
    final api = await _api();
    return api.getVirtualAccountStatus();
  }

  /// Create NGN Virtual Account explicitly (user action).
  /// Accepts optional KYC payload; returns backend response.
  Future<Map<String, dynamic>> createVirtualAccount({
    Map<String, dynamic>? kyc,
  }) async {
    final api = await _api();
    return api.createVirtualAccount(data: kyc);
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
  Future<Map<String, dynamic>> getCollectionDetails({
    required String country, // 'NG', 'KE', 'UG', ...
    String? method, // 'momo' or 'bank'
  }) async {
    final api = await _api();
    return api.getCollectionDetails(country: country, method: method);
  }

  // ---------------- Transactions (recent) ----------------

  /// Fetch recent fiat transactions (optionally filtered by currency code), default 3.
  /// Uses the paginated `/api/transactions/` behind the scenes and normalizes to a list of maps.
  Future<List<Map<String, dynamic>>> fetchRecentTransactions({
    String? currency,
    int limit = 3,
  }) async {
    final api = await _api();
    final list =
        await api.listFiatTransactions(currency: currency, limit: limit);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------- Test/Admin Utilities ----------------

  /// Credit a wallet (admin/test). Server path: `/api/wallets/add-money/`
  /// Live backend expects `{ currency, amount, narration? }` — no wallet_id/reference.
  Future<Map<String, dynamic>> creditWallet({
    required String currency, // e.g., 'NGN'
    required String amount, // keep as string
    String? narration,
  }) async {
    final api = await _api();
    return api.creditWallet(
      currency: currency,
      amount: amount,
      narration: narration,
    );
  }

  /// Back-compat shim (avoid if possible). Prefer addMoneyToWalletId or creditWallet above.
  @Deprecated('Use addMoneyToWalletId(...) or creditWallet(...) instead.')
  Future<Map<String, dynamic>> creditWalletLegacy({
    required String walletId,
    required String amount,
    String reference = 'test-credit',
    String narration = 'Test credit from app',
  }) async {
    final api = await _api();
    return api.creditWallet(
      currency: 'NGN',
      amount: amount,
      narration: narration,
    );
  }
}
