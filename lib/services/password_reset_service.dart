import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osvan_app/screen/wallet/services/config_service.dart';

class PasswordResetError implements Exception {
  final String code;
  final String? details;
  PasswordResetError(this.code, {this.details});
  @override
  String toString() =>
      'PasswordResetError($code${details != null ? ": $details" : ""})';
}

class PasswordResetService {
  static const _requestPath = '/v1/auth/password/request-otp/';
  static const _resetPath = '/v1/auth/password/reset/';

  static Uri _requestUrl() => ConfigService.apiUri(_requestPath);
  static Uri _resetUrl() => ConfigService.apiUri(_resetPath);

  /// Start flow: send OTP email
  static Future<void> requestOtp({required String email}) async {
    final res = await http.post(
      _requestUrl(),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: jsonEncode({'email': email.trim()}),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;
    if (res.statusCode == 400) {
      final msg = _msg(res.body);
      throw PasswordResetError('validation', details: msg);
    }
    throw PasswordResetError('server_${res.statusCode}', details: res.body);
  }

  /// Complete flow: verify OTP and set new password
  static Future<void> resetWithOtp({
    required String email,
    required String otp, // 6 digits string
    required String password,
  }) async {
    final res = await http.post(
      _resetUrl(),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: jsonEncode(
          {'email': email.trim(), 'otp': otp.trim(), 'password': password}),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;
    if (res.statusCode == 400) {
      final msg = _msg(res.body);
      throw PasswordResetError('validation', details: msg);
    }
    throw PasswordResetError('server_${res.statusCode}', details: res.body);
  }

  static String _msg(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['error'] ?? m['detail'] ?? m['message'] ?? 'validation_error')
          .toString();
    } catch (_) {
      return 'validation_error';
    }
  }
}
