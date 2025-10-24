import 'dart:convert';

import 'package:http/http.dart' as http;
// ⬇️ use your actual config file
import 'package:osvan_app/screen/wallet/services/config_service.dart'
    show ConfigService;

import '../services/auth_service.dart'; // AuthService.getToken()

class LimitService {
  static const String _limitsPath = '/v1/profile/limits/';

  // If your config field is named differently, change `ConfigService.baseUrl` here.
  static Uri _url() => Uri.parse('${ConfigService.baseUrl}$_limitsPath');

  static Future<Map<String, dynamic>> getLimits() async {
    final token = await AuthService.getToken();
    final res = await http.get(
      _url(),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 401) {
      throw LimitServiceError('unauthorized');
    } else {
      throw LimitServiceError('server_error_${res.statusCode}',
          details: res.body);
    }
  }

  static Future<void> updateLimits({
    required int daily,
    required int monthly,
  }) async {
    final token = await AuthService.getToken();
    final body = json.encode({
      'daily_limit': daily,
      'monthly_limit': monthly,
    });

    final res = await http.put(
      _url(),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (res.statusCode == 200) {
      return;
    } else if (res.statusCode == 400) {
      final data = _safeJson(res.body);
      final msg =
          (data['error'] ?? data['detail'] ?? 'validation_error').toString();
      throw LimitServiceError('validation', details: msg);
    } else if (res.statusCode == 401) {
      throw LimitServiceError('unauthorized');
    } else {
      throw LimitServiceError('server_error_${res.statusCode}',
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

class LimitServiceError implements Exception {
  final String code;
  final String? details;
  LimitServiceError(this.code, {this.details});
  @override
  String toString() =>
      'LimitServiceError($code${details != null ? ": $details" : ""})';
}
