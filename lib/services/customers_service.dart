import 'dart:async';

import 'package:dio/dio.dart';
import 'package:osvan_app/services/api_client.dart';

class CustomersService {
  // ✅ FIX: backend is mounted under /api
  static const String _path = '/api/v1/customers/';

  /// Create customer if missing; return the normalized customer object.
  /// Backend already handles idempotency and normalization.
  static Future<Map<String, dynamic>> createOrFetch({
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    String? country, // you can pass full country name; backend derives code
    String? countryCode, // or pass dial code; backend will accept either
  }) async {
    final dio = ApiClient.shared.dio;

    final payload = <String, dynamic>{
      'email': email.trim(),
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (countryCode != null && countryCode.trim().isNotEmpty)
        'countryCode': countryCode.trim(),
      if (country != null && country.trim().isNotEmpty)
        'country': country.trim(),
    };

    try {
      final r = await dio.post(_path, data: payload);
      final data =
          (r.data is Map<String, dynamic>) ? r.data : <String, dynamic>{};
      // Our backend convention returns 200 with {status, message, data:{...}} or a normalized object.
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return (data['data'] as Map<String, dynamic>);
      }
      return data;
    } on DioException catch (e) {
      // If our backend ever responds 409 for "already exists but not fetchable", just bubble details.
      final body = e.response?.data;
      throw Exception(
          'CustomersService error: ${e.response?.statusCode} ${body is String ? body : body}');
    }
  }

  /// Convenience: build payload from /api/user/me response
  static Future<Map<String, dynamic>> ensureFromMe(
      Map<String, dynamic> me) async {
    final email = (me['email'] ?? '').toString();
    final first = (me['first_name'] ?? me['firstName'] ?? '').toString();
    final last = (me['last_name'] ?? me['lastName'] ?? '').toString();
    final phone = (me['phone'] ?? '').toString();
    // prefer explicit country if your profile has it; default Nigeria for now
    final country = ((me['country'] ?? '') as String).trim().isNotEmpty
        ? (me['country'] as String)
        : 'Nigeria';

    if (email.isEmpty) {
      throw Exception('ensureFromMe: profile has no email');
    }
    return createOrFetch(
      email: email,
      firstName: first,
      lastName: last,
      phone: phone.isNotEmpty ? phone : null,
      country: country,
    );
    // Note: backend derives countryCode from country if missing (per our contract).
  }
}
