import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../models/wallet.dart';
import '../services/wallets_service.dart';

class WalletsController extends GetxController {
  // --- Local storage for persistence ---
  final _box = GetStorage(); // requires GetStorage.init() in main()

  // --- State ---
  final wallets = <Wallet>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  // --- Dashboard-facing observables ---
  final RxString primaryCurrency = ''.obs; // e.g. 'NGN'
  final RxString primaryBalanceText = '—'.obs; // e.g. '0.00'

  /// Auto-load on init (safe to call from Dashboard too)
  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Fetch wallets and compute primary wallet summary for Dashboard
  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final list = await WalletsService.instance.fetchWallets();
      wallets.assignAll(list);

      // Try to honor saved primary currency; else compute NGN/first
      final saved = _box.read<String>('primary_currency') ?? '';
      final savedWallet = saved.isNotEmpty ? byCode(saved) : null;
      if (savedWallet != null) {
        _applyPrimary(savedWallet, persist: false); // already saved
      } else {
        _computePrimary(); // NGN or first wallet
      }
    } catch (e) {
      error.value = e.toString();
      // keep previous UI values if any
    } finally {
      isLoading.value = false;
    }
  }

  /// Choose a primary wallet (prefer NGN; else first), and expose currency+balance text.
  void _computePrimary() {
    if (wallets.isEmpty) {
      primaryCurrency.value = '';
      primaryBalanceText.value = '0.00';
      return;
    }

    // Prefer NGN if available, otherwise the first wallet
    Wallet primary = wallets.first;
    final ngn = wallets.firstWhereOrNull(
      (w) => w.currencyCode.toUpperCase() == 'NGN',
    );
    if (ngn != null) primary = ngn;

    _applyPrimary(primary, persist: true);
  }

  /// UI-triggered: set the primary wallet by currency code (e.g., 'USD').
  void setPrimaryByCode(String code) {
    final w = byCode(code);
    if (w == null) return;
    _applyPrimary(w, persist: true);
  }

  // --- Internal: write observables from a Wallet model
  void _applyPrimary(Wallet w, {bool persist = false}) {
    final code = w.currencyCode.toUpperCase();
    final bal = w.balance; // non-nullable double in your model

    primaryCurrency.value = code;
    primaryBalanceText.value = _formatBalance(bal);

    if (persist) {
      _box.write('primary_currency', code);
    }
  }

  String _formatBalance(double v) {
    // Keep simple; avoid Intl dependency here
    return v.toStringAsFixed(2);
  }

  // --- Helpers ---
  Wallet? byCode(String code) => wallets.firstWhereOrNull(
        (w) => w.currencyCode.toUpperCase() == code.toUpperCase(),
      );

  double sumByCode(String code) => wallets
      .where((w) => w.currencyCode.toUpperCase() == code.toUpperCase())
      .fold<double>(0, (s, w) => s + w.balance);
}
