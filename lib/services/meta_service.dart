import 'dart:convert';

import 'package:http/http.dart' as http;

/// Country returned by /meta/payout-countries/
/// Minimal shape used by Send = code, name, methods.
/// currency/min/max kept optional for backward compatibility (if backend supplies them).
class PayoutCountry {
  final String code;
  final String name; // "Nigeria"
  final List<String> methods; // ["bank_transfer","mobile_money"]
  final String? currency; // optional (legacy/static)
  final num? min; // optional (legacy/static)
  final num? max; // optional (legacy/static)

  PayoutCountry({
    required this.code,
    required this.name,
    required this.methods,
    this.currency,
    this.min,
    this.max,
  });

  factory PayoutCountry.fromJson(Map<String, dynamic> j) {
    final code = (j['code'] ?? j['country_code'] ?? '').toString();
    final name = (j['name'] ?? j['country'] ?? code).toString();
    final rawMethods = (j['methods'] ?? j['payout_methods'] ?? []) as List;
    final methods = rawMethods.map((e) => e.toString()).toList();

    // optional legacy fields
    final currency = j['currency']?.toString();
    final num? min = (j['min'] is num)
        ? j['min'] as num
        : num.tryParse(j['min']?.toString() ?? '');
    final num? max = (j['max'] is num)
        ? j['max'] as num
        : num.tryParse(j['max']?.toString() ?? '');

    return PayoutCountry(
      code: code,
      name: name,
      methods: methods,
      currency: currency,
      min: min,
      max: max,
    );
  }
}

/// Field returned by /meta/beneficiary-schema/
/// Backend normalizes to {name,label,type,required,...}
/// We expose `key` for your UI but map from either "name" (new) or "key" (old).
class BeneficiaryField {
  final String key; // backend "name"
  final String label;
  final String type; // "string" | "phone" | "select" | ...
  final bool requiredField;
  final List<String> options; // if present for selects

  BeneficiaryField({
    required this.key,
    required this.label,
    required this.type,
    required this.requiredField,
    required this.options,
  });

  factory BeneficiaryField.fromJson(Map<String, dynamic> j) {
    final key = (j['name'] ?? j['key'] ?? '').toString();
    final label =
        (j['label'] ?? j['title'] ?? key.replaceAll('_', ' ')).toString();
    final type = (j['type'] ?? 'string').toString();
    final requiredField = (j['required'] is bool)
        ? (j['required'] as bool)
        : (j['required']?.toString().toLowerCase() == 'true');
    final List<String> options =
        ((j['options'] ?? []) as List).map((e) => e.toString()).toList();

    return BeneficiaryField(
      key: key,
      label: label,
      type: type,
      requiredField: requiredField,
      options: options,
    );
  }
}

class MetaService {
  final String baseUrl; // e.g. 'https://fintech.osvan.africa/api/v1'
  final http.Client _client;

  MetaService(this.baseUrl, [http.Client? client])
      : _client = client ?? http.Client();

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse(baseUrl.endsWith('/') ? '$baseUrl$path' : '$baseUrl/$path')
          .replace(queryParameters: q);

  Future<List<PayoutCountry>> getPayoutCountries({bool refresh = false}) async {
    final res = await _client
        .get(_u('meta/payout-countries/', {if (refresh) 'refresh': '1'}));
    if (res.statusCode != 200) {
      throw Exception(_err(res, fallback: 'Failed to load payout countries'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['countries'] as List?) ?? const [];
    return list
        .map((e) => PayoutCountry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BeneficiaryField>> getBeneficiarySchema({
    required String country,
    required String method,
    bool refresh = false,
  }) async {
    final res = await _client.get(_u('meta/beneficiary-schema/', {
      'country': country,
      'method': method,
      if (refresh) 'refresh': '1',
    }));
    if (res.statusCode != 200) {
      throw Exception(_err(res, fallback: 'Failed to load beneficiary schema'));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final fields = (data['fields'] as List?) ?? const [];
    return fields
        .map((e) => BeneficiaryField.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _err(http.Response r, {required String fallback}) {
    try {
      final m = jsonDecode(r.body);
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return fallback;
  }
}
