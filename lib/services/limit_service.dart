// lib/services/limit_service.dart
import 'package:dio/dio.dart';

import 'api/api_paths.dart';
import 'api/core_client.dart';

class LimitServiceError implements Exception {
  final String code;
  final String? details;
  LimitServiceError(this.code, {this.details});

  @override
  String toString() =>
      'LimitServiceError($code${details != null ? ": $details" : ""})';
}

class LimitService {
  static String _msg(dynamic data, {String fallback = 'Request failed'}) {
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final msg = (m['detail'] ?? m['error'] ?? m['message'] ?? fallback)
            .toString()
            .trim();
        if (msg.isNotEmpty) return msg;

        // try field errors: {"daily_limit":["..."]}
        if (m.isNotEmpty) {
          m.keys.first.toString();
          final v = m[m.keys.first];
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    } catch (_) {}
    return fallback;
  }

  static Future<Map<String, dynamic>> getLimits() async {
    await CoreClient.ensure();
    try {
      final res = await CoreClient.I.dio.get(ApiPaths.profileLimits);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw LimitServiceError('server', details: 'Unexpected response');
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      if (sc == 401) throw LimitServiceError('unauthorized');
      throw LimitServiceError(
        sc == 400 ? 'validation' : 'server_error_$sc',
        details: _msg(e.response?.data, fallback: 'Could not load limits'),
      );
    } catch (e) {
      throw LimitServiceError('server', details: e.toString());
    }
  }

  static Future<void> updateLimits({
    required int daily,
    required int monthly,
  }) async {
    await CoreClient.ensure();
    try {
      // your backend likely supports PATCH (ProfileApi uses PATCH)
      await CoreClient.I.dio.patch(
        ApiPaths.profileLimits,
        data: {
          'daily_limit': daily,
          'monthly_limit': monthly,
        },
      );
      return;
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      if (sc == 401) throw LimitServiceError('unauthorized');

      if (sc == 400) {
        throw LimitServiceError(
          'validation',
          details: _msg(e.response?.data, fallback: 'validation_error'),
        );
      }

      throw LimitServiceError(
        'server_error_$sc',
        details: _msg(e.response?.data, fallback: 'Failed to update limits'),
      );
    }
  }
}
