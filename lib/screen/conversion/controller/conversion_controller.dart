// lib/screen/conversion/controller/conversion_controller.dart
import 'package:get/get.dart';
// (These imports are safe even if controllers aren't registered at runtime)
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/screen/conversion/models/conversion_models.dart';
import 'package:osvan_app/screen/conversion/services/conversion_service.dart';
import 'package:osvan_app/screen/dashboard/controller/dashboard_controller.dart';

class ConversionController extends GetxController {
  final ConversionService svc;

  ConversionController({ConversionService? service})
      : svc = service ?? ConversionService();

  // form fields
  final from = 'USD'.obs;
  final to = 'NGN'.obs;
  final network = ''.obs; // TRON/BSC/ETH when USDT involved
  final amount = ''.obs;

  // ui state
  final loading = false.obs;
  final error = RxnString();

  // results
  final lastQuote = Rxn<ConversionQuote>();
  final lastConfirm = Rxn<Map<String, dynamic>>();

  bool get needsNetwork {
    final f = from.value.toUpperCase();
    final t = to.value.toUpperCase();
    return f == 'USDT' || t == 'USDT';
  }

  Future<void> getQuote() async {
    error.value = null;
    lastQuote.value = null;
    loading.value = true;
    try {
      final q = await svc.quote(
        from: from.value,
        to: to.value,
        amount: _normalizedAmount(),
        network: needsNetwork ? network.value : null,
      );
      lastQuote.value = q;
    } catch (e) {
      error.value = 'Unable to fetch quote';
    } finally {
      loading.value = false;
    }
  }

  Future<void> confirm() async {
    if (loading.value) return;
    error.value = null;
    loading.value = true;
    try {
      final q = lastQuote.value;
      final ref =
          'conv-${from.value}-${to.value}-${DateTime.now().millisecondsSinceEpoch}';
      final res = await svc.confirm(
        from: from.value,
        to: to.value,
        amount: _normalizedAmount(),
        network: needsNetwork ? network.value : null,
        idempotencyKey: ref,
        reference: ref,
        quoteId: q?.quoteId,
        expectedReceive: q?.youReceive,
      );
      final normalized = <String, dynamic>{
        'from': res['from'] ?? q?.from,
        'to': res['to'] ?? q?.to,
        'network': res['network'] ?? q?.network,
        'amount': res['amount'] ?? q?.amount,
        'credited':
            res['credited'] ?? res['to_amount'] ?? res['you_receive'] ?? q?.youReceive,
        'rate': res['rate'] ?? q?.rate,
        'fee': res['fee'] ?? q?.fee,
        'quoteId': res['quoteId'] ?? res['quote_id'] ?? q?.quoteId,
        'expectedReceive': res['expectedReceive'] ?? q?.youReceive,
        'timestamp': res['timestamp'] ??
            DateTime.now().toIso8601String(),
        'summary': res['summary'] ?? q?.summary,
      };

      lastConfirm.value = normalized;

      // ───── Minimal refresh hooks (this is the fix) ─────
      // Refresh fiat wallets (Dashboard)
      try {
        final dc = Get.find<DashboardController>();
        // If your DashboardController exposes a dedicated refresh, call it.
        // Otherwise re-use whatever you already have:
        await dc.loadUser(); // harmless
        // and if you have a wallets reload method, call it here too.
        // e.g., await dc.loadWallets();
      } catch (_) {
        /* dashboard controller might not be registered on this route */
      }

      // Refresh crypto balances when USDT is involved
      if (from.value.toUpperCase() == 'USDT' ||
          to.value.toUpperCase() == 'USDT') {
        try {
          final cc = Get.find<CryptoController>();
          await cc.refreshAll();
        } catch (_) {/* crypto screen not mounted; ignore */}
      }
      // ───────────────────────────────────────────────────

      Get.snackbar('Success', res['summary'] ?? 'Conversion completed',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      error.value = 'Conversion failed';
    } finally {
      loading.value = false;
    }
  }

  String _normalizedAmount() {
    final raw = amount.value.trim();
    if (raw.isEmpty) return '0.00';
    final v = double.tryParse(raw) ?? 0.0;
    return v.toStringAsFixed(2);
  }
}
