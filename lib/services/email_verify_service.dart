import 'package:dio/dio.dart';

import 'api/api_paths.dart';
import 'api/core_client.dart';

class EmailVerifyServiceError implements Exception {
  final String message;
  final int? statusCode;
  EmailVerifyServiceError(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class EmailVerifyService {
  static String _msgFrom(dynamic data, {String fallback = 'Request failed'}) {
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return (m['detail'] ?? m['error'] ?? m['message'] ?? fallback)
            .toString();
      }
      if (data is String && data.trim().isNotEmpty) return data.trim();
    } catch (_) {}
    return fallback;
  }

  static Future<void> requestOtp() async {
    await CoreClient.ensure();
    try {
      await CoreClient.I.dio.post(ApiPaths.emailOtp);
    } on DioException catch (e) {
      throw EmailVerifyServiceError(
        _msgFrom(e.response?.data, fallback: 'Failed to request OTP'),
        statusCode: e.response?.statusCode,
      );
    }
  }

  static Future<void> verifyOtp(String code) async {
    await CoreClient.ensure();
    try {
      await CoreClient.I.dio.post(
        ApiPaths.emailVerify,
        data: {"code": code.trim()},
      );
    } on DioException catch (e) {
      throw EmailVerifyServiceError(
        _msgFrom(e.response?.data, fallback: 'Invalid or expired code'),
        statusCode: e.response?.statusCode,
      );
    }
  }
}
