// lib/services/change_password_service.dart
import 'package:dio/dio.dart';

import 'api/api_paths.dart';
import 'api/core_client.dart';

class ChangePasswordError implements Exception {
  final String code;
  final String? details;
  ChangePasswordError(this.code, {this.details});

  @override
  String toString() =>
      'ChangePasswordError($code${details != null ? ": $details" : ""})';
}

class ChangePasswordService {
  static String _msg(dynamic data, {String fallback = 'Request failed'}) {
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final msg =
            (m['detail'] ?? m['error'] ?? m['message'] ?? fallback).toString();
        if (msg.trim().isNotEmpty) return msg.trim();

        // handle field errors: {"old_password":["wrong password"]}
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

  static Future<void> change({
    required String oldPassword,
    required String newPassword,
  }) async {
    await CoreClient.ensure();

    try {
      await CoreClient.I.dio.post(
        ApiPaths.changePassword,
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      return;
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;

      if (sc == 401) {
        throw ChangePasswordError(
          'unauthorized',
          details: _msg(e.response?.data, fallback: 'Please log in again.'),
        );
      }

      if (sc == 400) {
        throw ChangePasswordError(
          'validation',
          details: _msg(e.response?.data, fallback: 'validation_error'),
        );
      }

      throw ChangePasswordError(
        'server',
        details: _msg(e.response?.data, fallback: 'Could not change password'),
      );
    } catch (e) {
      throw ChangePasswordError('server', details: e.toString());
    }
  }
}
