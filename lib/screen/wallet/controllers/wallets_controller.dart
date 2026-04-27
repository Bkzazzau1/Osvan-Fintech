import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/store/session_store.dart';

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
  final RxDouble primaryBalance = 0.0.obs; // numeric, for charts/math

  // Internal: prevent concurrent loads
  bool _busy = false;
  Timer? _refreshTimer;
  Timer? _initialRefreshTimer;
  static const Duration _initialRefreshDelay = Duration(seconds: 1);
  static const Duration _defaultRefreshInterval = Duration(seconds: 60);
  Duration _refreshInterval = _defaultRefreshInterval;

  @override
  void onInit() {
    super.onInit();
    // If a session already exists (e.g., returning user), bootstrap refresh.
    unawaited(startAutoRefresh());
  }

  @override
  void onClose() {
    _cancelTimers();
    super.onClose();
  }

  /// Fetch wallets and compute primary wallet summary for Dashboard
  Future<void> load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    if (!silent || wallets.isEmpty) {
      isLoading.value = true;
      error.value = null;
    }

    try {
      // 1) Fetch current wallets
      var list = await WalletsService.instance.fetchWallets();
      wallets.assignAll(list);

      // 2) If none, bootstrap defaults (NGN, USD) and refetch once
      if (wallets.isEmpty) {
        await _ensureDefaultWallets();
        list = await WalletsService.instance.fetchWallets();
        wallets.assignAll(list);
      } else {
        // If some exist but missing one of the defaults, create only the missing
        await _ensureMissingDefaults();
        // Optionally refetch if you want to reflect just-created wallet(s)
        list = await WalletsService.instance.fetchWallets();
        wallets.assignAll(list);
      }

      // 3) Try to honor saved primary currency; else compute NGN/first
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
      if (!silent || wallets.isEmpty) {
        isLoading.value = false;
      }
      _busy = false;
    }
  }

  /// Manual refresh (e.g., pull-to-refresh)
  Future<void> refreshWallets() => load();

  /// Ensure both NGN and USD exist if nothing exists yet.
  Future<void> _ensureDefaultWallets() async {
    // Create NGN first, then USD (ignore race/dup on server side)
    try {
      await WalletsService.instance.createWallet(currency: 'NGN');
    } catch (_) {
      // swallow — server might already have created it elsewhere
    }
    try {
      await WalletsService.instance.createWallet(currency: 'USD');
    } catch (_) {}
  }

  /// If some wallets exist but one of NGN/USD is missing, create the missing ones.
  Future<void> _ensureMissingDefaults() async {
    final hasNGN = wallets.any((w) => w.currencyCode.toUpperCase() == 'NGN');
    final hasUSD = wallets.any((w) => w.currencyCode.toUpperCase() == 'USD');

    if (!hasNGN) {
      try {
        await WalletsService.instance.createWallet(currency: 'NGN');
      } catch (_) {}
    }
    if (!hasUSD) {
      try {
        await WalletsService.instance.createWallet(currency: 'USD');
      } catch (_) {}
    }
  }

  /// Choose a primary wallet (prefer NGN; else first), and expose currency+balance
  void _computePrimary() {
    if (wallets.isEmpty) {
      primaryCurrency.value = '';
      primaryBalance.value = 0.0;
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
    final bal = w.balance; // double (non-nullable in your model)

    primaryCurrency.value = code;
    primaryBalance.value = bal;
    primaryBalanceText.value = _formatBalance(bal);

    if (persist) {
      _box.write('primary_currency', code);
    }
  }

  String _formatBalance(double v) {
    // Keep simple; avoid Intl dependency here
    return v.toStringAsFixed(2);
    // If you later add intl:
    // final f = NumberFormat('#,##0.00'); return f.format(v);
  }

  // --- Helpers ---
  Wallet? byCode(String code) => wallets.firstWhereOrNull(
        (w) => w.currencyCode.toUpperCase() == code.toUpperCase(),
      );

  double sumByCode(String code) => wallets
      .where((w) => w.currencyCode.toUpperCase() == code.toUpperCase())
      .fold<double>(0, (s, w) => s + w.balance);

  /// Start periodic wallet refreshes. Does nothing if not authenticated.
  ///
  /// Flow:
  ///   1. Run an immediate load to populate UI.
  ///   2. Fire a follow-up refresh after [_initialRefreshDelay] (~1s).
  ///   3. Continue refreshing every [_refreshInterval] (default 60s).
  Future<void> startAutoRefresh({
    Duration? interval,
    Duration initialDelay = _initialRefreshDelay,
  }) async {
    _refreshInterval = interval ?? _refreshInterval;
    _cancelTimers();

    if (!await SessionStore.instance.isLoggedIn) return;

    await load();

    _initialRefreshTimer = Timer(initialDelay, () {
      load(silent: true);
      _refreshTimer = Timer.periodic(
        _refreshInterval,
        (_) => load(silent: true),
      );
    });
  }

  /// Stop timers and optionally clear local state (used on logout).
  void stopAutoRefresh({bool clearState = false}) {
    _cancelTimers();
    if (clearState) {
      wallets.clear();
      primaryCurrency.value = '';
      primaryBalance.value = 0.0;
      primaryBalanceText.value = '-';
    }
  }

  void _cancelTimers() {
    _initialRefreshTimer?.cancel();
    _refreshTimer?.cancel();
    _initialRefreshTimer = null;
    _refreshTimer = null;
  }
}
