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
  // Back-end paths (Django)
  static const String _registerPath = '/auth/register/';
  static const String _otpRequestPath = '/auth/email/otp/';
  static const String _otpVerifyPath = '/auth/email/verify/';

  static Uri _url(String path) => ConfigService.apiUri(path);

  /// Create a Django user account. Backend only requires: email, password, firstName?, lastName?
  /// We’ll map your UI fields to the expected keys and safely ignore extras server-side.
  static Future<void> register({
    required String email,
    required String surname, // maps to lastName
    required String firstName, // maps to firstName
    String? middleName, // ignored by backend for now
    required String dateOfBirth, // ignored by backend for now (yyyy-MM-dd)
    required String phone, // ignored by backend for now
    required String country, // ignored by backend for now
    required String password,
    required String address, // ignored by backend for now
  }) async {
    final body = json.encode({
      // Backend fields (used)
      "email": email.trim(),
      "password": password,
      "firstName": firstName.trim(),
      "lastName": surname.trim(),

      // Extra profile fields (currently ignored by backend; safe to send for future use)
      "middleName": (middleName ?? "").trim(),
      "dateOfBirth": dateOfBirth, // yyyy-MM-dd
      "phone": phone.trim(),
      "country": country.trim(),
      "address": address.trim(),
    });

    final res = await http.post(
      _url(_registerPath),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: body,
    );

    if (res.statusCode == 200) {
      final data = _safeJson(res.body);
      if (data['ok'] == true) return;
      throw RegisterServiceError('validation',
          details: (data['error'] ??
                  data['detail'] ??
                  data['message'] ??
                  'registration_failed')
              .toString());
    } else if (res.statusCode == 400) {
      final data = _safeJson(res.body);
      throw RegisterServiceError('validation',
          details: (data['error'] ??
                  data['detail'] ??
                  data['message'] ??
                  'validation_error')
              .toString());
    } else {
      throw RegisterServiceError('server_error_${res.statusCode}',
          details: res.body);
    }
  }

  /// Request email OTP. Returns `debugCode` in dev/int environments (null in prod).
  static Future<String?> requestEmailOtp({required String email}) async {
    final res = await http.post(
      _url(_otpRequestPath),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: json.encode({"email": email.trim()}),
    );

    final data = _safeJson(res.body);
    if (res.statusCode == 200 && data['ok'] == true) {
      return data['debugCode']
          as String?; // will be present only when DJANGO_ENV != "prod"
    } else if (res.statusCode == 400) {
      throw RegisterServiceError('validation',
          details: (data['error'] ??
                  data['detail'] ??
                  data['message'] ??
                  'otp_request_failed')
              .toString());
    } else {
      throw RegisterServiceError('server_error_${res.statusCode}',
          details: res.body);
    }
  }

  /// Verify email OTP.
  static Future<void> verifyEmailOtp(
      {required String email, required String code}) async {
    final res = await http.post(
      _url(_otpVerifyPath),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: json.encode({"email": email.trim(), "code": code.trim()}),
    );

    final data = _safeJson(res.body);
    if (res.statusCode == 200 && data['ok'] == true) {
      return;
    } else if (res.statusCode == 400) {
      throw RegisterServiceError('validation',
          details: (data['error'] ??
                  data['detail'] ??
                  data['message'] ??
                  'invalid_or_expired_code')
              .toString());
    } else if (res.statusCode == 404) {
      throw RegisterServiceError('not_found',
          details: (data['error'] ?? 'user_not_found').toString());
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
