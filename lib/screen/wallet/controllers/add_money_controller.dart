// lib/features/add_money/controllers/add_money_controller.dart
import 'package:get/get.dart';
// USE THE CORRECT PATH FOR YOUR PROJECT:
import 'package:osvan_app/screen/wallet/services/wallets_service.dart';
// or: import 'package:osvan_app/features/wallets/services/wallets_service.dart';

class AddMoneyController extends GetxController {
  final _svc = WalletsService();

  /// Selected wallet currency code, e.g. 'NGN' | 'KES' | 'UGX'
  final selectedCurrency = 'NGN'.obs;

  /// Status: PENDING | CREATING | READY | FAILED
  final status = 'PENDING'.obs;

  /// Current VA data when READY (account_name, bank_name, account_number, ...)
  final va = Rxn<Map<String, dynamic>>();

  /// UI flags/messages
  final busy = false.obs;
  final message = ''.obs;

  bool get isNGN => selectedCurrency.value.toUpperCase() == 'NGN';

  @override
  void onInit() {
    super.onInit();
    // Recheck VA status whenever currency switches
    ever<String>(selectedCurrency, (_) => _maybeLoadVAStatus());
    _maybeLoadVAStatus();
  }

  Future<void> _maybeLoadVAStatus() async {
    if (!isNGN) {
      // Never call VA endpoints for KES/UGX
      status.value = 'PENDING';
      va.value = null;
      _setOk(
        'Collections are currently unavailable for ${selectedCurrency.value}.',
      );
      return;
    }

    busy.value = true;
    try {
      final res =
          await _svc.getVirtualAccountStatus(); // fast GET (no creation)
      final s = (res['status'] ?? 'READY').toString().toUpperCase();
      status.value = s;

      if (s == 'READY') {
        va.value = res;
        _setOk();
      } else if (s == 'PENDING') {
        va.value = null;
        _setOk('Create your NGN receiving account to fund by bank transfer.');
      } else if (s == 'CREATING') {
        va.value = null;
        _setOk('Creating your receiving account...');
      } else if (s == 'FAILED') {
        va.value = null;
        _setErr((res['error'] ?? 'Creation failed. Tap Try Again.').toString());
      }
    } catch (_) {
      status.value = 'PENDING';
      va.value = null;
      _setErr('Unable to check receiving account. Pull to refresh.');
    } finally {
      busy.value = false;
    }
  }

  /// Explicit user action: tap "Get Receiving Account" (NGN only)
  Future<void> createVA({Map<String, dynamic>? kyc}) async {
    if (!isNGN) return;

    busy.value = true;
    _setOk('Creating your receiving account...');
    try {
      // Kick off creation (returns 202 or READY)
      await _svc.createVirtualAccount(kyc: kyc);

      // Poll for READY for up to ~60s
      final ready = await _svc.waitForVAReady();
      if (ready != null) {
        va.value = ready;
        status.value = 'READY';
        _setOk();
      } else {
        status.value = 'CREATING';
        _setOk('Still creating… Tap Refresh in a moment.');
      }
    } catch (e) {
      status.value = 'FAILED';
      _setErr('Creation failed. ${e.toString()}');
    } finally {
      busy.value = false;
    }
  }

  /// Manual refresh (pull-to-refresh or button)
  Future<void> refreshVA() => _maybeLoadVAStatus();

  // ---------------- Back-compat shims for existing view code ----------------

  /// Old: controller.loadVA() -> now points to refreshVA()
  Future<void> loadVA() => refreshVA();

  /// Old: controller.isLoadingVA -> map to busy
  RxBool get isLoadingVA => busy;

  /// Old: controller.vaError -> mirror error messages here
  final RxnString _vaError = RxnString();
  RxnString get vaError => _vaError;

  // Keep _vaError in sync with message/errors
  void _setOk([String m = '']) {
    message.value = m;
    _vaError.value = null;
  }

  void _setErr(String m) {
    message.value = m;
    _vaError.value = m;
  }
}
