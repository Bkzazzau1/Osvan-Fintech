// ignore_for_file: constant_identifier_names, equal_elements_in_set

import 'dart:convert'; // ✅ needed for jsonDecode

import 'package:dio/dio.dart';
import 'package:osvan_app/services/api/api_paths_payouts.dart';
import 'package:osvan_app/services/api/core_client.dart';

/// SAFE path builder for payout transaction status
String payoutTxStatusFor(String transactionId) =>
    '/api/payout/tx/${transactionId.trim()}/';

/// ✅ Correct backend resolve/lookup endpoint
String payoutResolveFor(String countryCode) =>
    '/api/payout/resolve/${countryCode.toUpperCase()}/';

class PayoutsApi {
  PayoutsApi._(this._dio);

  static PayoutsApi? _instance;
  final Dio _dio;

  static Future<PayoutsApi> ensureInitialized() async {
    await CoreClient.ensure();
    _instance ??= PayoutsApi._(CoreClient.I.dio);
    return _instance!;
  }

  static PayoutsApi get I =>
      _instance ??
      (throw StateError(
          'PayoutsApi not initialized. Call ensureInitialized().'));

  // ─────────────────────────── Helpers ───────────────────────────

  int toMinor(String currency, double major) {
    // Project rule: all Brails amounts are minor units
    return (major * 100).round();
  }

  /// Tolerant unwrap (Map|List) via CoreClient
  dynamic _uw(dynamic body) => CoreClient.I.unwrap(body);

  bool _looksLikeCurrency(String s) =>
      s.isNotEmpty && s.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(s);

  // ✅ Normalize provider method aliases into app-facing values.
  String _normalizeType(String t) {
    final v = t.toUpperCase().trim();
    if (v == 'NUBAN' ||
        v == 'BANK_ACCOUNT' ||
        v == 'ACCOUNT' ||
        v == 'ACCOUNT_NUMBER') {
      return 'BANK';
    }
    if (v == 'MOBILEMONEY' || v == 'MOBILE_MONEY') return 'MOBILE_NUMBER';
    return v;
  }

  // ─────────────────────────── Lookups ───────────────────────────

  /// Fetch full corridor list from backend (Brails proxy).
  /// Accepts shapes:
  ///   { "countries": [...] } | { "data":[...] } | [ ... ]
  Future<List<dynamic>> supportedCountries() async {
    final List<String> candidates = <String>{
      '/api/payout/countries/',
      ApiPathsPayoutExt.payoutSupportedCountries,
      '/payout/countries/',
      '/api/payout/supported/',
    }.toList();

    for (final path in candidates) {
      try {
        final r = await _dio.get(path);
        final raw = _uw(r.data);

        if (raw is List) return raw;

        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          final list = map['countries'] ?? map['data'] ?? map['results'] ?? [];
          if (list is List) return list;
        }
      } catch (_) {
        // try next candidate
      }
    }
    return const [];
  }

  /// Country requirements/schema (always return the inner schema Map).
  /// Backend: GET /api/payout/requirements/{COUNTRY}/?channel=METHOD
  /// Accepts shapes:
  ///   { "schema":{...} } | { ... } (already schema)
  Future<Map<String, dynamic>> countryRequirements(
    String country, {
    required String channel,
  }) async {
    final r = await _dio.get(
      ApiPathsPayoutExt.payoutRequirementsFor(country),
      queryParameters: {'channel': channel.toUpperCase()},
    );
    final raw = _uw(r.data);

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m['schema'] is Map) {
        return Map<String, dynamic>.from(m['schema'] as Map);
      }
      return m;
    }
    return <String, dynamic>{};
  }

  /// Banks for corridor.
  /// IMPORTANT: your backend requires currency (CURRENCY_REQUIRED), so we always try:
  ///   /api/payout/banks/?country=XX&currency=YYY
  Future<List<Map<String, dynamic>>> supportedBanks(
    String country,
    String currency,
  ) async {
    final upperCountry = country.toUpperCase().trim();
    final upperCurrency = currency.toUpperCase().trim();

    Response<dynamic>? r;
    dynamic raw;

    // 1) Preferred canonical: query params with currency (backend requires it)
    if (_looksLikeCurrency(upperCurrency)) {
      try {
        r = await _dio.get(
          '/api/payout/banks/',
          queryParameters: {
            'country': upperCountry,
            'currency': upperCurrency,
          },
        );
        raw = _uw(r.data);
      } catch (_) {}
    }

    // 2) Fallback: some corridors might accept country-only (rare)
    if (raw == null) {
      try {
        r = await _dio.get(
          '/api/payout/banks/',
          queryParameters: {'country': upperCountry},
        );
        raw = _uw(r.data);
      } catch (_) {}
    }

    // 3) Legacy path fallbacks (keep, but they’ll still fail if currency missing)
    if (raw == null) {
      final List<String> candidates = <String>{
        ApiPathsPayoutExt.payoutBanksFor(country, currency),
        if (_looksLikeCurrency(upperCurrency))
          '/api/payout/banks/$upperCountry/$upperCurrency/',
        if (_looksLikeCurrency(upperCurrency))
          '/api/payout/banks/$upperCountry/$upperCurrency',
        '/api/payout/banks/$upperCountry/',
      }.toList();

      for (final path in candidates) {
        try {
          r = await _dio.get(path);
          raw = _uw(r.data);
          if (raw != null) break;
        } catch (_) {}
      }
    }

    List list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw['data'] is List) {
      list = raw['data'] as List;
    } else if (raw is Map && raw['banks'] is List) {
      list = raw['banks'] as List;
    } else if (raw is Map && raw['results'] is List) {
      list = raw['results'] as List;
    } else if (raw is Map && raw['items'] is List) {
      list = raw['items'] as List;
    } else {
      list = const [];
    }

    return list
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e);
          final name =
              (m['name'] ?? m['bankName'] ?? m['label'] ?? '').toString();
          final code = (m['code'] ??
                  m['bankCode'] ??
                  m['nipBankCode'] ??
                  m['swiftCode'] ??
                  m['bic'] ??
                  '')
              .toString();
          final curr = (m['currency'] ?? upperCurrency).toString();
          return {'name': name, 'code': code, 'currency': curr};
        })
        .where((m) =>
            (m['code'] as String).isNotEmpty &&
            (m['name'] as String).isNotEmpty)
        .toList();
  }

  /// ✅ Resolve beneficiary name (optional; backend enforces lookup rules).
  /// Backend: POST /api/payout/resolve/{CC}/
  ///
  /// Stable response shape:
  ///  { status:true, lookupAvailable:bool, message:String, data:{accountName,...} | null }
  Future<Map<String, dynamic>> resolveName({
    required String country,
    required String type, // BANK | MOBILE_NUMBER
    required String accountNumber,
    String? currency,
    String? bankCode,
    String? network, // GH momo e.g. MTN
  }) async {
    // ✅ normalize
    final cc = country.toUpperCase().trim();
    final t = _normalizeType(type); // BANK or MOBILE_NUMBER

    // ✅ FIX: for NG + BANK lookup, DO NOT send currency
    final isNgBankLookup = (cc == 'NG' && t == 'BANK');

    // ✅ never send empty currency
    final ccy = (currency ?? '').trim().toUpperCase();

    final body = <String, dynamic>{
      'type': t,
      'accountNumber': accountNumber.trim(),
      if (cc.isNotEmpty) 'country': cc,

      // ✅ only include currency when allowed
      if (!isNgBankLookup && ccy.isNotEmpty) 'currency': ccy,

      if (bankCode != null && bankCode.trim().isNotEmpty)
        'bankCode': bankCode.trim(),
      if (network != null && network.trim().isNotEmpty)
        'network': network.trim(),
    };

    // ✅ resilient catch so UI never breaks
    try {
      final r = await _dio.post(payoutResolveFor(cc), data: body);
      final raw = _uw(r.data);

      // ✅ tolerate Map or JSON string
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final j = jsonDecode(raw);
          if (j is Map) return Map<String, dynamic>.from(j);
        } catch (_) {}
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{
        'status': true,
        'lookupAvailable': false,
        'message': 'Lookup unavailable. You may continue.',
        'data': null,
      };
    }
  }

  // ───────────────────── Beneficiaries ─────────────────────

  /// Create a beneficiary.
  /// Backend: POST /api/payout/beneficiaries/
  /// Backend auto-generates reference + provider callbackUrl internally.
  Future<Map<String, dynamic>> createBeneficiary({
    required String country,
    required String channel,
    required String currency,
    required String customerEmail,
    required Map<String, dynamic> destination,
    String? nickname,
  }) async {
    final payload = {
      'country': country.toUpperCase(),
      'channel': channel.toUpperCase(),
      'currency': currency.toUpperCase(),
      'customerEmail': customerEmail,
      'destination': destination,
      if (nickname != null && nickname.trim().isNotEmpty)
        'nickname': nickname.trim(),
    };

    final r =
        await _dio.post(ApiPathsPayoutExt.payoutBeneficiaries, data: payload);
    final raw = _uw(r.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// Company-level list (Brails scope). We'll stop calling this from UI later.
  /// Backend: GET /api/payout/beneficiaries/list/?page=&take=
  Future<List<dynamic>> listBeneficiaries({int page = 1, int take = 10}) async {
    const listPath = '/api/payout/beneficiaries/list/';

    try {
      final r = await _dio.get(
        listPath,
        queryParameters: {'page': page, 'take': take},
      );
      final raw = _uw(r.data);

      if (raw is List) return raw;
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final data = (m['data'] is Map)
            ? Map<String, dynamic>.from(m['data'])
            : const <String, dynamic>{};
        final list = data['beneficiaries'];
        return list is List ? list : const [];
      }
    } catch (_) {}

    return const [];
  }

  Future<Map<String, dynamic>> getBeneficiary(String beneficiaryId) async {
    final r = await _dio
        .get(ApiPathsPayoutExt.payoutBeneficiaryDetail(beneficiaryId));
    final raw = _uw(r.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  // ───────────────────────────── Payouts ─────────────────────────────

  /// Initialize payout (backend contract).
  /// Backend: POST /api/payout/init/
  /// Body:
  ///   country,currency,amountCents,beneficiaryId,description,customerEmail,sourceWalletCurrency, reference?
  Future<Map<String, dynamic>> init({
    required String country,
    required String currency,
    required int amountCents,
    required String beneficiaryId,
    required String description,
    required String customerEmail,
    String sourceWalletCurrency = 'USD',
    String? reference,
  }) async {
    final payload = {
      'country': country.toUpperCase(),
      'currency': currency.toUpperCase(),
      'amountCents': amountCents,
      'beneficiaryId': beneficiaryId,
      'description': description,
      'customerEmail': customerEmail,
      'sourceWalletCurrency': sourceWalletCurrency.toUpperCase(),
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
    };

    final r = await _dio.post(ApiPathsPayoutExt.payoutInit, data: payload);
    final raw = _uw(r.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// Finalize payout: backend needs transactionId and PIN.
  Future<Map<String, dynamic>> finalize({
    required String transactionId,
    required String pin,
  }) async {
    final payload = {
      'transactionId': transactionId,
      'pin': pin,
    };

    final r = await _dio.post(ApiPathsPayoutExt.payoutFinalize, data: payload);
    final raw = _uw(r.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// Attach document (if your backend exposes the route).
  Future<Map<String, dynamic>> attachDocument({
    required String transactionId,
    required String documentType,
    required String base64File,
  }) async {
    final r = await _dio.post(
      ApiPathsPayoutExt.payoutAttachDocumentFor(transactionId),
      data: {'type': documentType, 'file': base64File},
    );
    final raw = _uw(r.data);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  // ─────────────────────── Payout status polling ───────────────────────

  /// Poll payout transaction status from backend.
  /// Backend: GET /api/payout/tx/{transactionId}/
  /// Returns provider wrapper {status:true,data:{...}}; we return the inner data map.
  Future<Map<String, dynamic>?> pollPayoutStatus(
    String transactionId, {
    int attempts = 12,
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (transactionId.isEmpty) return null;

    for (var i = 0; i < attempts; i++) {
      await Future.delayed(interval);

      final r = await _dio.get(payoutTxStatusFor(transactionId));
      final raw = _uw(r.data);

      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final data =
            (m['data'] is Map) ? Map<String, dynamic>.from(m['data']) : null;

        if (data != null) {
          final s = (data['status'] ?? '').toString().toUpperCase();

          const terminal = {
            'SUCCESS',
            'COMPLETED',
            'FAILED',
            'REVERSED',
            'CANCELED',
            'CANCELLED',
          };

          if (terminal.contains(s)) return data;
        }
      }
    }
    return null;
  }
}
