import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osvan_app/screen/wallet/services/config_service.dart';

import '../services/auth_service.dart'; // AuthService.getToken()

class CloseAccountError implements Exception {
  final String code;
  final String? details;
  CloseAccountError(this.code, {this.details});
  @override
  String toString() =>
      'CloseAccountError($code${details != null ? ": $details" : ""})';
}

class CloseAccountService {
  // Adjust to your actual backend route
  static const _path = '/v1/profile/account-close/request/';

  static Uri _url() => ConfigService.apiUri(_path);

  /// Submits an account closure request with an optional reason.
  static Future<void> submit({String? reason}) async {
    final token = await AuthService.getToken();
    final res = await http.post(
      _url(),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'reason': (reason ?? '').trim(),
      }),
    );

    if (res.statusCode == 200 ||
        res.statusCode == 201 ||
        res.statusCode == 204) {
      return;
    }

    if (res.statusCode == 400) {
      final msg = _msg(res.body);
      throw CloseAccountError('validation', details: msg);
    }
    if (res.statusCode == 401) {
      throw CloseAccountError('unauthorized',
          details: 'Session expired. Please log in again.');
    }
    throw CloseAccountError('server_${res.statusCode}', details: res.body);
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
