// lib/screen/transfer/controllers/payout/mixins/payout_schema_mixin.dart

import 'package:osvan_app/services/api/payouts_api.dart';

import '../payout_base.dart';

mixin PayoutSchemaMixin on PayoutWizardBase {
  @override
  Future<void> loadRequirement() async {
    isLoading.value = true;
    try {
      await PayoutsApi.ensureInitialized();

      // Backend requires channel param.
      final channel =
          destination.value.trim().isEmpty ? 'BANK' : destination.value;

      // Returns the INNER schema map.
      final sch = await PayoutsApi.I.countryRequirements(
        countryCode.value,
        channel: channel,
      );

      requirement.value = Map<String, dynamic>.from(sch);

      // IMPORTANT:
      // Do NOT override `methods`, `destination`, or `currency` here anymore.
      // Those are now sourced from /api/payout/countries/ and controlled by the controller.
      // This prevents the UI from being stuck on BANK.

      buildFieldsFor(destination.value);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void buildFieldsFor(String method) {
    final sch = requirement.value ?? const <String, dynamic>{};

    List<dynamic>? list;

    // 1) destination: { BANK: [...], MOBILEMONEY: [...] }
    final dest = sch['destination'];
    if (dest is Map && dest[method] is List) {
      list = dest[method] as List;
    }
    // 2) top-level method array: { BANK: [...] }
    else if (sch[method] is List) {
      list = sch[method] as List;
    }
    // 3) generic fields: { fields: [...] }
    else if (sch['fields'] is List) {
      list = sch['fields'] as List;
    }

    final normalized = <Map<String, dynamic>>[];
    if (list is List) {
      for (final f in list) {
        if (f is Map) normalized.add(Map<String, dynamic>.from(f));
      }
    }

    fields
      ..clear()
      ..addAll(normalized);

    // Seed const/defaults into form
    for (final f in fields) {
      final name = (f['name'] ?? f['key'] ?? '').toString();
      if (name.isEmpty) continue;
      if (f.containsKey('const')) form[name] = f['const'];
      if (!form.containsKey(name) && f.containsKey('default')) {
        form[name] = f['default'];
      }
    }

    // Inline banks if present on a field named "bankCode"
    banks.clear();
    for (final f in fields) {
      final fname = (f['name'] ?? f['key'] ?? '').toString().toLowerCase();
      if (fname == 'bankcode' && f['banks'] is List) {
        final rawInlineBanks = (f['banks'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final normalizedInlineBanks = rawInlineBanks
            .map((m) => <String, dynamic>{
                  'name': (m['name'] ?? m['bankName'] ?? m['label'] ?? '')
                      .toString(),
                  'code': (m['code'] ??
                          m['bankCode'] ??
                          m['nipBankCode'] ??
                          m['swiftCode'] ??
                          m['bic'] ??
                          '')
                      .toString(),
                  'currency': (m['currency'] ?? '').toString(),
                })
            .toList();

        banks
          ..clear()
          ..addAll(_dedupBanks(normalizedInlineBanks));
        break;
      }
    }

    _normalizeSelectedBankCode();
  }

  // ─── local helpers ───
  List<Map<String, String>> _dedupBanks(List<Map<String, dynamic>> raw) {
    final seen = <String>{};
    final out = <Map<String, String>>[];

    for (final m in raw) {
      final name = (m['name'] ?? '').toString().trim();
      final code = (m['code'] ?? '').toString().trim();
      if (name.isEmpty || code.isEmpty) continue;

      final key = '$code|$name'.toUpperCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      out.add({
        'name': name,
        'code': code,
        'currency': (m['currency'] ?? '').toString(),
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
