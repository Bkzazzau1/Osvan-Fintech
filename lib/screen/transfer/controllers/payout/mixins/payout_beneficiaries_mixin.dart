// lib/screen/transfer/controllers/payout/mixins/payout_beneficiaries_mixin.dart

import 'package:osvan_app/services/api/payouts_api.dart';

import '../payout_base.dart';

mixin PayoutBeneficiariesMixin on PayoutWizardBase {
  // NG/GH account-name resolution
  @override
  Future<void> resolveAccountName() async {
    final cc = countryCode.value.toUpperCase();
    final destType = destination.value.toUpperCase();

    // ✅ backend rule:
    // NG -> BANK only
    // GH -> MOBILE_NUMBER only
    final needs = (cc == 'NG' && destType == 'BANK') ||
        (cc == 'GH' && destType == 'MOBILE_NUMBER');
    if (!needs) return;

    final an = (form['accountNumber'] ?? '').toString().trim();
    if (an.length < 8) return;

    // BANK needs bankCode; GH momo needs network
    final bc = (form['bankCode'] ?? '').toString().trim();
    final net = (form['network'] ?? '').toString().trim();

    final canResolve = (cc == 'NG' && destType == 'BANK' && bc.isNotEmpty) ||
        (cc == 'GH' && destType == 'MOBILE_NUMBER' && net.isNotEmpty);
    if (!canResolve) return;

    resolvingName.value = true;
    try {
      await PayoutsApi.ensureInitialized();

      final res = await PayoutsApi.I.resolveName(
        country: cc,
        type: destType, // BANK or MOBILE_NUMBER
        accountNumber: an,
        currency: currency.value,
        bankCode: bc.isEmpty ? null : bc,
        network: net.isEmpty ? null : net,
      );

      // ✅ lookup is optional; backend is source of truth
      final lookupAvailable = (res['lookupAvailable'] == true);

      // If lookup is not available, do not block user and do not throw.
      if (!lookupAvailable) return;

      final data = res['data'];
      final name =
          (data is Map ? (data['accountName'] ?? '') : '').toString().trim();

      if (name.isEmpty) throw 'Account name not found';

      form['accountName'] = name;
      resolvedName.value = name;
    } finally {
      resolvingName.value = false;
    }
  }

  // List saved beneficiaries
  @override
  Future<void> loadBeneficiaries() async {
    isLoading.value = true;
    try {
      await PayoutsApi.ensureInitialized();
      final list = await PayoutsApi.I.listBeneficiaries(page: 1, take: 50);

      beneficiaries
        ..clear()
        ..addAll(
          list
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
    } finally {
      isLoading.value = false;
    }
  }

  // Apply a saved beneficiary to the form
  void selectBeneficiary(Map<String, dynamic> bene) async {
    selectedBeneficiary.value = bene;

    final dest = Map<String, dynamic>.from(
      (bene['destination'] ?? bene['data']?['destination'] ?? const {}),
    );

    final type = (dest['type'] ?? '').toString().toUpperCase();
    if (type.isNotEmpty) destination.value = type;

    if (bene['country'] is String && (bene['country'] as String).isNotEmpty) {
      countryCode.value = (bene['country'] as String).toUpperCase();
    }
    if (bene['currency'] is String && (bene['currency'] as String).isNotEmpty) {
      currency.value = (bene['currency'] as String).toUpperCase();
    }

    await loadRequirement();
    await loadBanksIfNeeded();
    buildFieldsFor(destination.value);

    for (final entry in dest.entries) {
      form[entry.key.toString()] = entry.value;
    }

    final id = (bene['id'] ?? bene['beneficiaryId'] ?? bene['data']?['id'])
        ?.toString();
    if (id != null && id.isNotEmpty) beneficiaryId.value = id;
  }

  // Concrete payload builder
  @override
  Map<String, dynamic> buildDestinationFromSchema() {
    final Map<String, dynamic> out = {'type': destination.value};

    void setDeep(Map obj, List<String> path, dynamic value) {
      Map cur = obj;
      for (int i = 0; i < path.length; i++) {
        final k = path[i];
        if (i == path.length - 1) {
          cur[k] = value;
        } else {
          if (cur[k] is! Map) cur[k] = <String, dynamic>{};
          cur = cur[k] as Map;
        }
      }
    }

    for (final f in fields) {
      final name = (f['name'] ?? f['key'] ?? '').toString();
      if (name.isEmpty) continue;

      final hasConst = f.containsKey('const');
      final dynamic rawVal = hasConst ? f['const'] : form[name];

      if (!hasConst &&
          (rawVal == null || (rawVal is String && rawVal.trim().isEmpty))) {
        continue;
      }

      final type = (f['type'] ?? 'string').toString().toLowerCase();
      dynamic val = rawVal;

      if (rawVal is String) {
        if (type == 'number' || type == 'integer') {
          final n = num.tryParse(rawVal);
          if (n != null) val = (type == 'integer') ? n.toInt() : n;
        } else if (type == 'boolean') {
          val = (rawVal.toLowerCase() == 'true' || rawVal == '1');
        }
      }

      setDeep(out, name.split('.'), val);
    }

    // Fill sender.country if path exists but empty
    dynamic cur = out;
    for (final k in ['sender', 'country']) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        cur = null;
        break;
      }
    }
    if (cur is String && cur.trim().isEmpty) {
      final root = out;
      if (root['sender'] is! Map) root['sender'] = <String, dynamic>{};
      (root['sender'] as Map)['country'] = countryCode.value;
    }

    return out;
  }

  Future<String> saveBeneficiaryOnly() async {
    await PayoutsApi.ensureInitialized();

    final payloadDest = Map<String, dynamic>.from(buildDestinationFromSchema());

    final email = (form['customerEmail'] ?? '').toString().trim();
    if (email.isEmpty) throw 'Missing customer email';

    final res = await PayoutsApi.I.createBeneficiary(
      country: countryCode.value,
      channel: destination.value,
      currency: currency.value,
      customerEmail: email,
      destination: payloadDest,
      nickname: (form['nickname'] ?? '').toString().trim().isEmpty
          ? null
          : (form['nickname']).toString().trim(),
    );

    final String id =
        (res['data']?['id'] ?? res['id'] ?? res['beneficiaryId'] ?? '')
            .toString();

    if (id.isEmpty) throw 'Could not save beneficiary';
    beneficiaryId.value = id;

    await loadBeneficiaries();
    return id;
  }

  Future<void> ensureBeneficiary() async {
    if ((beneficiaryId.value ?? '').isNotEmpty) return;

    await PayoutsApi.ensureInitialized();

    final dest = Map<String, dynamic>.from(buildDestinationFromSchema());

    final email = (form['customerEmail'] ?? '').toString().trim();
    if (email.isEmpty) throw 'Missing customer email';

    final res = await PayoutsApi.I.createBeneficiary(
      country: countryCode.value,
      channel: destination.value,
      currency: currency.value,
      customerEmail: email,
      destination: dest,
      nickname: (form['nickname'] ?? '').toString().trim().isEmpty
          ? null
          : (form['nickname']).toString().trim(),
    );

    final String? id =
        (res['data']?['id'] ?? res['id'] ?? res['beneficiaryId'])?.toString();

    if (id == null || id.isEmpty) throw 'Unable to create beneficiary';
    beneficiaryId.value = id;
  }

  Future<void> initPayout() async {
    if (beneficiaryId.value == null || beneficiaryId.value!.isEmpty) {
      await ensureBeneficiary();
    }

    await PayoutsApi.ensureInitialized();

    final email =
        (form['customerEmail'] ?? 'user@example.com').toString().trim();
    final desc = (form['description'] ?? 'Payout').toString().trim();
    final srcWallet =
        (form['sourceWalletCurrency'] ?? 'USD').toString().trim().toUpperCase();

    final amountCents = PayoutsApi.I.toMinor(currency.value, amountMajor.value);

    final res = await PayoutsApi.I.init(
      country: countryCode.value,
      currency: currency.value,
      amountCents: amountCents,
      beneficiaryId: beneficiaryId.value!,
      description: desc.isEmpty ? 'Payout' : desc,
      customerEmail: email,
      sourceWalletCurrency: srcWallet.isEmpty ? 'USD' : srcWallet,
    );

    final map = Map<String, dynamic>.from(res);
    initResponse.value = map;

    final String? txId =
        (map['data']?['transactionId'] ?? map['transactionId'])?.toString();

    if (txId == null || txId.isEmpty) throw 'Missing transaction id';
    transactionId.value = txId;
  }

  Future<void> finalizePayout({required String pin}) async {
    final tx = transactionId.value;
    if (tx == null || tx.isEmpty) throw 'Missing transaction id';
    await PayoutsApi.ensureInitialized();
    await PayoutsApi.I.finalize(transactionId: tx, pin: pin);
  }

  String statusOf(Map<String, dynamic> m) {
    final ok =
        (m['ok'] == true) || (m['status'] == true) || (m['success'] == true);
    if (ok) return 'SUCCESS';
    final s = (m['state'] ?? m['status'] ?? '').toString().toUpperCase();
    return s.isNotEmpty ? s : 'PENDING';
  }
}
