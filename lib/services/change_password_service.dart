import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osvan_app/screen/wallet/services/config_service.dart';

import '../services/auth_service.dart'; // AuthService.getToken()

class ChangePasswordError implements Exception {
  final String code;
  final String? details;
  ChangePasswordError(this.code, {this.details});
  @override
  String toString() =>
      'ChangePasswordError($code${details != null ? ": $details" : ""})';
}

class ChangePasswordService {
  static const _path = '/v1/auth/password/change/';

  static Uri _url() => ConfigService.apiUri(_path);

  static Future<void> change({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await AuthService.getToken();
    final res = await http.post(
      _url(),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;

    if (res.statusCode == 400) {
      final msg = _msg(res.body);
      throw ChangePasswordError('validation', details: msg);
    }
    if (res.statusCode == 401) {
      throw ChangePasswordError('unauthorized',
          details: 'Session expired. Please log in again.');
    }
    throw ChangePasswordError('server_${res.statusCode}', details: res.body);
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
