// lib/controllers/dashboard_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:osvan_app/models/user_me.dart';
import 'package:osvan_app/services/api_client.dart';
import 'package:osvan_app/services/customers_service.dart'; // ✅ ensure Brails customer

class DashboardController extends GetxController {
  // ---- User (from /api/user/me/) ----
  final user = Rxn<UserMe>();

  // ---- Reactive wallet balance (existing) ----
  var walletBalance = 0.00.obs;

  // ---- Selected tab/index state (existing) ----
  var selectedIndex = 0.obs;
  bool _loadedUser = false;
  bool _loadingUser = false;

  @override
  void onInit() {
    super.onInit();
    fetchWalletBalance(); // existing mock
    _safeLoadUser(); // load user once on init
  }

  /// Load profile once after login and cache in memory.
  /// Also ensures Brails customer exists (idempotent) based on the profile.
  Future<void> loadUser() async {
    if (_loadedUser || _loadingUser) return;
    _loadingUser = true;

    try {
      final api = await ApiClient.ensureInitialized();
      final me = await api.getMe(); // raw Map from /api/user/me
      user.value = UserMe.fromMap(me); // keep your model
      _loadedUser = true;

      // ✅ Ensure Brails customer exists using the same profile map
      unawaited(_ensureCustomer(me));
    } finally {
      _loadingUser = false;
    }
  }

  Future<void> _ensureCustomer(Map<String, dynamic> me) async {
    try {
      await CustomersService.ensureFromMe(me);
    } catch (_) {
      // Don’t block dashboard if provider temporarily fails
    }
  }

  // Robust wrapper so UI doesn’t crash if backend is momentarily unreachable
  Future<void> _safeLoadUser() async {
    try {
      await loadUser();
    } catch (_) {
      // optional: add retry/backoff or set a fallback state
    }
  }

  // ---------------- wallet balance (existing) ----------------
  // Simulated API call to fetch wallet balance (replace with real API later)
  void fetchWalletBalance() {
    walletBalance.value = 15000.00; // Example balance
  }

  // Manual update of wallet balance
  void updateBalance(double newBalance) {
    walletBalance.value = newBalance;
  }

  // ---------------- navigation helpers (existing) ----------------
  void incrementIndex() {
    if (selectedIndex.value < 4) {
      selectedIndex.value++;
    }
  }

  void resetIndex() {
    selectedIndex.value = 0;
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }
}
