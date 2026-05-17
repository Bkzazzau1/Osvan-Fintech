// lib/screen/transfer/controllers/payout/mixins/payout_banks_mixin.dart

import 'package:osvan_app/services/api/payouts_api.dart';

import '../payout_base.dart';

mixin PayoutBanksMixin on PayoutWizardBase {
  bool _looksLikeCurrency(String s) =>
      s.isNotEmpty && s.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(s);

  String _fallbackCurrencyForIso2(String iso2) {
    // Minimal safe defaults (add more as you expand)
    switch (iso2) {
      case 'NG':
        return 'NGN';
      case 'GH':
        return 'GHS';
      case 'UG':
        return 'UGX';
      case 'KE':
        return 'KES';
      case 'RW':
        return 'RWF';
      case 'TZ':
        return 'TZS';
      case 'ZA':
        return 'ZAR';
      case 'US':
        return 'USD';
      case 'GB':
        return 'GBP';
      default:
        return ''; // unknown → we'll try currency.value first
    }
  }

  @override
  Future<void> loadBanksIfNeeded() async {
    final method = destination.value.toUpperCase().trim();
    if (method != 'BANK' && method != 'NUBAN') {
      banks.clear();
      return;
    }

    // If schema already provided banks, don't refetch
    if (banks.isNotEmpty) return;

    isLoading.value = true;
    try {
      await PayoutsApi.ensureInitialized();

      final iso2 = countryCode.value.trim().toUpperCase();

      // IMPORTANT: always pass a real 3-letter currency for banks endpoint.
      final fromState = currency.value.trim().toUpperCase();
      final fallback = _fallbackCurrencyForIso2(iso2);

      final ccy = _looksLikeCurrency(fromState)
          ? fromState
          : (_looksLikeCurrency(fallback) ? fallback : fromState);

      final res = await PayoutsApi.I.supportedBanks(iso2, ccy);

      final rows = res
          .map<Map<String, String>>((m) => {
                'name': (m['name'] ?? '').toString(),
                'code': (m['code'] ?? '').toString(),
                'currency': (m['currency'] ?? ccy).toString(),
              })
          .toList();

      banks
        ..clear()
        ..addAll(_dedupBanks(rows));

      _normalizeSelectedBankCode();
    } finally {
      isLoading.value = false;
    }
  }

  // local helpers
  List<Map<String, String>> _dedupBanks(List<Map<String, String>> raw) {
    final seen = <String>{};
    final out = <Map<String, String>>[];

    for (final e in raw) {
      final name = (e['name'] ?? '').toString().trim();
      final code = (e['code'] ?? '').toString().trim();
      if (name.isEmpty || code.isEmpty) continue;

      final key = '$code|$name'.toUpperCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      out.add({
        'name': name,
        'code': code,
        'currency': (e['currency'] ?? '').toString(),
      });
    }
    return out;
  }

  void _normalizeSelectedBankCode() {
    final current = (form['bankCode'] ?? '').toString();
    if (current.isEmpty) return;
    final exists = banks.any((b) => b['code'] == current);
    if (!exists) form.remove('bankCode');
  }
}
