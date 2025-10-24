import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osvan_app/screen/wallet/services/config_service.dart';

class RegisterServiceError implements Exception {
  final String code;
  final String? details;
  RegisterServiceError(this.code, {this.details});
  @override
  String toString() =>
      'RegisterServiceError($code${details != null ? ": $details" : ""})';
}

class RegisterService {
  // Adjust path to your real endpoint
  static const String _path = '/v1/auth/register/';

  static Uri _url() => ConfigService.apiUri(_path);

  static Future<void> register({
    required String email,
    required String surname,
    required String firstName,
    String? middleName,
    required String dateOfBirth, // ISO yyyy-MM-dd
    required String phone,
    required String country,
    required String password,
    required String address,
  }) async {
    final body = json.encode({
      "email": email.trim(),
      "surname": surname.trim(),
      "first_name": firstName.trim(),
      "middle_name": (middleName ?? "").trim(),
      "date_of_birth": dateOfBirth, // "1992-04-23"
      "phone": phone.trim(),
      "country": country.trim(),
      "password": password,
      "address": address.trim(),
    });

    final res = await http.post(
      _url(),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: body,
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return;
    } else if (res.statusCode == 400) {
      final data = _safeJson(res.body);
      final msg = (data['error'] ??
              data['detail'] ??
              data['message'] ??
              'validation_error')
          .toString();
      throw RegisterServiceError('validation', details: msg);
    } else {
      throw RegisterServiceError('server_error_${res.statusCode}',
          details: res.body);
    }
  }

  static Map<String, dynamic> _safeJson(String s) {
    try {
      return json.decode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
