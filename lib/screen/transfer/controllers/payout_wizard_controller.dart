// lib/screen/transfer/controllers/payout_wizard_controller.dart
// Main orchestrator; composes mixins without circular deps.

// ignore_for_file: unnecessary_type_check

import 'package:get/get.dart';
import 'package:osvan_app/screen/transfer/controllers/payout/mixins/payout_banks_mixin.dart';
import 'package:osvan_app/screen/transfer/controllers/payout/mixins/payout_beneficiaries_mixin.dart';
import 'package:osvan_app/screen/transfer/controllers/payout/mixins/payout_schema_mixin.dart';
import 'package:osvan_app/screen/transfer/controllers/payout/payout_base.dart';
// ✅ NEW (backend email source)
import 'package:osvan_app/services/api/api_paths.dart';
import 'package:osvan_app/services/api/core_client.dart';
import 'package:osvan_app/services/api/payouts_api.dart';

class PayoutWizardController extends PayoutWizardBase
    with PayoutSchemaMixin, PayoutBanksMixin, PayoutBeneficiariesMixin {
  // Loading
  @override
  final isLoading = false.obs;

  // Step
  @override
  final step = 1.obs; // 1 Destination, 2 Details, 3 Confirm

  // Selections
  @override
  final countries = <Map<String, String>>[]
      .obs; // each row includes: code,name,currency,methodsCsv
  @override
  final countryCode = 'NG'.obs;
  @override
  final currency = 'NGN'.obs;
  @override
  final destination =
      'BANK'.obs; // BANK | MOBILEMONEY | SWIFT | ACH | WIRE | SEPA_EUR | ...

  // Schema + lookups
  @override
  final requirement = Rxn<Map<String, dynamic>>();
  @override
  final banks = <Map<String, String>>[].obs;
  @override
  final methods = <String>[].obs;
  @override
  final fields = <Map<String, dynamic>>[].obs;

  // Form + amount
  @override
  final form = <String, dynamic>{}.obs;
  @override
  final amountMajor = 0.0.obs;

  // Results
  @override
  final beneficiaryId = RxnString();
  @override
  final initResponse = Rxn<Map<String, dynamic>>();
  @override
  final transactionId = RxnString();

  // ✅ NEW: keep last init response for debugging
  final lastInitResponse = Rxn<Map<String, dynamic>>();

  // Beneficiaries (NOTE: company-wide endpoint exists but we won't load it for Flutter users)
  @override
  final beneficiaries = <Map<String, dynamic>>[].obs;
  @override
  final selectedBeneficiary = Rxn<Map<String, dynamic>>();

  // Resolver state
  @override
  final resolvingName = false.obs;
  @override
  final resolvedName = RxnString();

  // ✅ backend-driven lookup gating
  final lookupAvailable = false.obs;
  final lookupMessage = ''.obs;

  // ✅ NEW: backend email cache (single source of truth)
  final backendEmail = RxnString();

  Future<String> _getBackendEmail() async {
    final cached = (backendEmail.value ?? '').trim();
    if (cached.isNotEmpty) return cached;

    await CoreClient.ensure();

    final r = await CoreClient.I.dio.get(ApiPaths.userMe);
    final raw = CoreClient.I.unwrap(r.data);

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);

      // tolerate shapes: {email:...} OR {data:{email:...}}
      final direct = (m['email'] ?? '').toString().trim();
      if (direct.isNotEmpty) {
        backendEmail.value = direct;
        return direct;
      }

      if (m['data'] is Map) {
        final d = Map<String, dynamic>.from(m['data'] as Map);
        final e = (d['email'] ?? '').toString().trim();
        if (e.isNotEmpty) {
          backendEmail.value = e;
          return e;
        }
      }
    }

    throw Exception('Unable to read email from backend. Please login again.');
  }

  // ✅ 1) Normalize method names (prevents GH mismatch)
  String _normMethod(String v) {
    final m = v.toUpperCase().trim();
    if (m == 'MOBILEMONEY' || m == 'MOBILE_MONEY') return 'MOBILE_NUMBER';
    return m;
  }

  bool get _needsNameResolution {
    final cc = countryCode.value.toUpperCase();
    final dest = _normMethod(destination.value);

    // ✅ Nigeria: BANK only
    if (cc == 'NG' && dest == 'BANK') return true;

    // ✅ Ghana: MOBILE_NUMBER only (MoMo)
    if (cc == 'GH' && dest == 'MOBILE_NUMBER') return true;

    return false;
  }

  // ✅ UI can hide resolve button unless it might apply
  bool get showResolveButton => _needsNameResolution;

  @override
  bool get canResolveAccount {
    final cc = countryCode.value.toUpperCase();
    final dest = _normMethod(destination.value);

    final an = (form['accountNumber'] ?? '').toString().trim();

    // ✅ Standard: NG bank account number must be exactly 10 digits
    if (cc == 'NG' && dest == 'BANK') {
      if (!RegExp(r'^\d{10}$').hasMatch(an)) return false;
      final bc = (form['bankCode'] ?? '').toString().trim();
      return bc.isNotEmpty;
    }

    // ✅ Ghana MoMo can vary, keep your original rule (>=8) + network required
    if (cc == 'GH' && dest == 'MOBILE_NUMBER') {
      if (an.length < 8) return false;
      final net = (form['network'] ?? '').toString().trim(); // e.g. MTN
      return net.isNotEmpty;
    }

    // default
    if (an.length < 8) return false;
    return false;
  }

  @override
  bool get allowProceed {
    if (!_needsNameResolution) return true;

    // ✅ If backend says lookup not available, do NOT block user
    if (!lookupAvailable.value) return true;

    // ✅ If lookup is available, require name
    final name = (form['accountName'] ?? '').toString().trim();
    return name.isNotEmpty;
  }

  Future<void> resolveNow() async {
    if (!canResolveAccount) return;

    resolvingName.value = true;
    resolvedName.value = null;
    resolvedName.refresh();

    lookupAvailable.value = false;
    lookupMessage.value = '';
    form.remove('accountName');
    form.refresh();

    try {
      await PayoutsApi.ensureInitialized();

      final cc = countryCode.value.toUpperCase();
      final dest = _normMethod(destination.value);

      final accountNumber = (form['accountNumber'] ?? '').toString().trim();
      final bankCode = (form['bankCode'] ?? '').toString().trim();
      final network = (form['network'] ?? '').toString().trim();

      // ✅ Don’t pass empty currency
      final ccy = currency.value.trim().toUpperCase();

      final res = await PayoutsApi.I.resolveName(
        country: cc,
        type: dest, // BANK or MOBILE_NUMBER
        currency: ccy.isEmpty ? null : ccy,
        bankCode: bankCode.isEmpty ? null : bankCode,
        accountNumber: accountNumber,
        network: network.isEmpty ? null : network,
      );

      final la = (res['lookupAvailable'] == true);
      lookupAvailable.value = la;
      lookupMessage.value = (res['message'] ?? '').toString();

      final dynamic data = (res['data'] is Map) ? res['data'] : res;
      final name = (data is Map) ? (data['accountName'] ?? '').toString() : '';

      if (name.trim().isNotEmpty) {
        final trimmed = name.trim();
        resolvedName.value = trimmed;
        resolvedName.refresh();

        form['accountName'] = trimmed;
        form.refresh();
      } else {
        resolvedName.value = null;
        resolvedName.refresh();

        form.remove('accountName');
        form.refresh();
      }
    } catch (e) {
      lookupAvailable.value = false;
      lookupMessage.value = 'Lookup failed. You can continue.';

      resolvedName.value = null;
      resolvedName.refresh();

      form.remove('accountName');
      form.refresh();
    } finally {
      resolvingName.value = false;
    }
  }

  // Countries list (prefer NG → GH → first)
  @override
  Future<void> loadCountries() async {
    isLoading.value = true;
    try {
      await PayoutsApi.ensureInitialized();
      final raw = await PayoutsApi.I.supportedCountries();
      final iterable = (raw is List) ? raw : const <dynamic>[];

      final seen = <String>{};
      final mapped = <Map<String, String>>[];

      for (final e in iterable) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);

        final code =
            (m['code'] ?? m['iso2'] ?? m['countryCode'] ?? m['country'] ?? '')
                .toString()
                .toUpperCase()
                .trim();

        final name = (m['name'] ?? m['countryName'] ?? code).toString().trim();

        if (code.isEmpty || seen.contains(code)) continue;
        seen.add(code);

        final currencies = (m['currencies'] is List)
            ? (m['currencies'] as List).map((x) => x.toString()).toList()
            : <String>[];
        final defaultCurrency =
            currencies.isNotEmpty ? currencies.first.toUpperCase() : '';

        final pm = (m['paymentMethods'] is List)
            ? (m['paymentMethods'] as List)
                .map((x) => x.toString().toUpperCase())
                .toList()
            : <String>[];
        final methodsCsv = pm.join(',');

        mapped.add({
          'code': code,
          'name': name,
          'currency': defaultCurrency,
          'methods': methodsCsv,
        });
      }

      countries.assignAll(mapped);

      String? pick;
      if (mapped.any((c) => c['code'] == 'NG')) {
        pick = 'NG';
      } else if (mapped.any((c) => c['code'] == 'GH')) {
        pick = 'GH';
      } else if (mapped.isNotEmpty) {
        pick = mapped.first['code'];
      }

      if (pick != null) {
        countryCode.value = pick;
        await onSelectCountry(pick);
      } else {
        methods.clear();
        fields.clear();
        banks.clear();
      }
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, String>? _countryRow(String iso2) {
    final code = iso2.toUpperCase().trim();
    for (final row in countries) {
      if ((row['code'] ?? '').toString().toUpperCase() == code) return row;
    }
    return null;
  }

  @override
  Future<void> onSelectCountry(String iso2) async {
    final iso = iso2.toUpperCase().trim();
    countryCode.value = iso;

    final row = _countryRow(iso);
    final ccy = (row?['currency'] ?? '').toString().trim().toUpperCase();
    if (ccy.isNotEmpty) {
      currency.value = ccy;
    }

    final methodsCsv = (row?['methods'] ?? '').toString();
    final ms = methodsCsv
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    methods
      ..clear()
      ..addAll(ms.isEmpty ? const ['BANK'] : ms);

    if (methods.isNotEmpty && !methods.contains(destination.value)) {
      destination.value = methods.first;
    }

    banks.clear();
    form.remove('bankCode');
    form.remove('bankName');

    resolvedName.value = null;
    resolvedName.refresh();

    lookupAvailable.value = false;
    lookupMessage.value = '';
    form.remove('accountName');
    form.refresh();

    await loadRequirement();
    await loadBanksIfNeeded();
  }

  @override
  Future<void> onSelectMethod(String method) async {
    destination.value = method.toUpperCase().trim();
    buildFieldsFor(destination.value);
    await loadBanksIfNeeded();

    final dest = _normMethod(destination.value);
    if (dest != 'BANK') {
      form.remove('bankCode');
      form.remove('bankName');
    }

    resolvedName.value = null;
    resolvedName.refresh();

    lookupAvailable.value = false;
    lookupMessage.value = '';
    form.remove('accountName');
    form.refresh();
  }

  Future<String> _customerEmailOrEmpty() async {
    return _getBackendEmail();
  }

  String _descriptionOrDefault() {
    final d = (form['description'] ?? '').toString().trim();
    if (d.isNotEmpty) return d;
    return 'Payout transfer';
  }

  // ✅ NEW: minor unit factor by currency
  int _minorUnitFactor() {
    final ccy = currency.value.toUpperCase().trim();
    if (ccy == 'NGN') return 100;
    if (ccy == 'USD') return 100;
    return 100; // default
  }

  // ✅ FIXED: always send provider amount in MINOR units (kobo/cents)
  int _amountCents() {
    final v = amountMajor.value;
    if (v <= 0) return 0;

    final factor = _minorUnitFactor();
    final minor = (v * factor).round();
    return minor <= 0 ? 0 : minor;
  }

  // ✅ FIX: Nigeria -> NGN source wallet, Others -> USD source wallet
  String _sourceWalletCurrencyOrDefault() {
    final v = (form['sourceWalletCurrency'] ?? form['sourceCurrency'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (v.isNotEmpty) return v;

    final cc = countryCode.value.toUpperCase().trim();
    return (cc == 'NG') ? 'NGN' : 'USD';
  }

  Future<void> _createBeneficiaryIfMissing() async {
    final existing = (beneficiaryId.value ?? '').toString().trim();
    if (existing.isNotEmpty) return;

    final sel = selectedBeneficiary.value;
    if (sel is Map) {
      final id = (sel?['id'] ?? sel?['beneficiaryId'] ?? '').toString().trim();
      if (id.isNotEmpty) {
        beneficiaryId.value = id;
        return;
      }
    }

    final cc = countryCode.value.toUpperCase();
    final dest = _normMethod(destination.value);
    final ccy = currency.value.toUpperCase().trim();

    final email = await _customerEmailOrEmpty();
    if (email.isEmpty) {
      throw Exception('Missing customer email. Please login again.');
    }

    final destinationObj = <String, dynamic>{
      ...form,
      'type': dest,
      'channel': dest,
      'country': cc,
      'currency': ccy,
    };

    final created = await PayoutsApi.I.createBeneficiary(
      country: cc,
      channel: destination.value.toUpperCase().trim(),
      currency: ccy,
      customerEmail: email,
      destination: destinationObj,
    );

    final data = (created['data'] is Map) ? created['data'] : created;
    final id = (data['id'] ?? data['beneficiaryId'] ?? '').toString().trim();

    if (id.isEmpty) {
      throw Exception(
          'Beneficiary created but missing id from backend response');
    }

    beneficiaryId.value = id;
  }

  // ✅ NEW: resilient transactionId extractor (supports multiple shapes)
  String _pickTransactionId(Map<String, dynamic> resMap) {
    // preferred: resMap.data.transactionId
    final data = resMap['data'];
    if (data is Map) {
      final d = Map<String, dynamic>.from(data);
      final v1 = d['transactionId'];
      final v2 = d['transaction_id'];
      if (v1 is String && v1.trim().isNotEmpty) return v1.trim();
      if (v2 is String && v2.trim().isNotEmpty) return v2.trim();
    }

    // fallback: top-level
    final v3 = resMap['transactionId'];
    final v4 = resMap['transaction_id'];
    if (v3 is String && v3.trim().isNotEmpty) return v3.trim();
    if (v4 is String && v4.trim().isNotEmpty) return v4.trim();

    return '';
  }

  @override
  Future<void> initPayout() async {
    isLoading.value = true;
    try {
      await PayoutsApi.ensureInitialized();

      await _createBeneficiaryIfMissing();

      final txAmount = _amountCents();
      if (txAmount <= 0) {
        throw Exception('Invalid amount');
      }

      final email = await _customerEmailOrEmpty();
      if (email.isEmpty) {
        throw Exception('Missing customer email. Please login again.');
      }

      final desc = _descriptionOrDefault();
      final sourceCur = _sourceWalletCurrencyOrDefault();

      final cc = countryCode.value.toUpperCase();
      final ccy = currency.value.toUpperCase().trim();
      final bid = (beneficiaryId.value ?? '').toString().trim();

      if (bid.isEmpty) {
        throw Exception('Missing beneficiary id');
      }

      final res = await PayoutsApi.I.init(
        country: cc,
        currency: ccy,
        amountCents: txAmount,
        sourceWalletCurrency: sourceCur,
        beneficiaryId: bid,
        customerEmail: email,
        description: desc,
        reference: (form['reference'] ?? '').toString().trim().isNotEmpty
            ? (form['reference'] ?? '').toString().trim()
            : null,
      );

      // ✅ safe cast (prevents empty initResponse)
      final Map<String, dynamic> resMap = (res is Map)
          ? Map<String, dynamic>.from(res as Map)
          : <String, dynamic>{};

      // keep for debugging
      lastInitResponse.value = resMap;

      // ✅ stop misleading “Missing transaction id” when init returns error
      if (resMap['error'] != null) {
        final err = resMap['error'];
        final msg = (err is Map ? (err['message'] ?? err['code']) : null)
                ?.toString()
                .trim() ??
            'Init payout failed';
        throw Exception(msg);
      }

      initResponse.value = resMap;

      // ✅ Extract tx id using resilient picker
      final txId = _pickTransactionId(resMap);

      if (txId.isEmpty) {
        throw Exception('Missing transaction id from init payout');
      }

      transactionId.value = txId;
    } finally {
      isLoading.value = false;
    }
  }
}
