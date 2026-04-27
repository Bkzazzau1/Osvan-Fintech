// lib/services/close_account_service.dart
import 'package:dio/dio.dart';

import 'api/api_paths.dart';
import 'api/core_client.dart';

class CloseAccountError implements Exception {
  final String code;
  final String? details;
  CloseAccountError(this.code, {this.details});

  @override
  String toString() =>
      'CloseAccountError($code${details != null ? ": $details" : ""})';
}

class CloseAccountService {
  static String _msg(dynamic data, {String fallback = 'Request failed'}) {
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return (m['detail'] ?? m['error'] ?? m['message'] ?? fallback)
            .toString()
            .trim();
      }
      if (data is String && data.trim().isNotEmpty) return data.trim();
    } catch (_) {}
    return fallback;
  }

  static Future<void> submit({String? reason}) async {
    await CoreClient.ensure();

    try {
      await CoreClient.I.dio.post(
        ApiPaths.profileCloseAccount,
        data: {
          'reason': (reason ?? '').trim(),
        },
      );
      return;
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;

      if (sc == 401) {
        throw CloseAccountError(
          'unauthorized',
          details: 'Session expired. Please log in again.',
        );
      }

      if (sc == 400) {
        throw CloseAccountError(
          'validation',
          details: _msg(e.response?.data, fallback: 'validation_error'),
        );
      }

      throw CloseAccountError(
        'server_$sc',
        details: _msg(e.response?.data, fallback: 'Could not submit request'),
      );
    } catch (e) {
      throw CloseAccountError('server', details: e.toString());
    }
  }
}
