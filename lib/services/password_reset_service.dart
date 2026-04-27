import 'package:dio/dio.dart' as dio;
import 'package:osvan_app/services/api/api_paths.dart';
import 'package:osvan_app/services/api/core_client.dart';

class PasswordResetError implements Exception {
  final String code;
  final String? details;
  PasswordResetError(this.code, {this.details});
  @override
  String toString() =>
      'PasswordResetError($code${details != null ? ": $details" : ""})';
}

class PasswordResetService {
  static const _requestPath = ApiPaths.resetPasswordRequest;
  static const _confirmPath = ApiPaths.resetPasswordConfirm;

  /// Start flow: send OTP email
  static Future<Map<String, dynamic>> requestOtp({required String email}) async {
    await CoreClient.ensure();
    final client = CoreClient.I.dio;

    final res = await client.post(
      _requestPath,
      data: {'email': email.trim()},
      options: dio.Options(headers: {'X-Skip-Auth': '1'}),
    );

    final data = _map(res.data);
    if (_ok(res.statusCode, data)) return data;

    throw PasswordResetError(
      'request_failed',
      details: _pickMessage(data) ?? 'Could not send OTP',
    );
  }

  /// Complete flow: verify OTP and set new password
  static Future<Map<String, dynamic>> resetWithOtp({
    required String email,
    required String otp, // 6 digits string
    required String password,
  }) async {
    await CoreClient.ensure();
    final client = CoreClient.I.dio;

    final res = await client.post(
      _confirmPath,
      data: {
        'email': email.trim(),
        'code': otp.trim(),
        'new_password': password,
      },
      options: dio.Options(headers: {'X-Skip-Auth': '1'}),
    );

    final data = _map(res.data);
    if (_ok(res.statusCode, data)) return data;

    throw PasswordResetError(
      'reset_failed',
      details: _pickMessage(data) ?? 'Reset failed',
    );
  }

  static bool _ok(int? status, Map<String, dynamic> data) {
    if (status != null && status >= 200 && status < 300) return true;
    final flag = data['ok'] ?? data['status'] ?? data['success'];
    return flag == true;
  }

  static String? _pickMessage(Map<String, dynamic> data) {
    final candidates = ['message', 'detail', 'error', 'code', 'debug'];
    for (final key in candidates) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)));
    }
    return <String, dynamic>{};
  }
}
