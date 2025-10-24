// lib/controllers/mixins/auth_guard.dart
// GetX mixin to standardize Dio error → snackbar mapping and guard calls.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

mixin AuthGuard {
  /// Wrap an API action and handle errors to UX.
  Future<T?> guard<T>(
    Future<T> Function() action, {
    VoidCallback? onUnauthorized,
    String successMessage = '',
  }) async {
    try {
      final result = await action();
      if (successMessage.isNotEmpty) {
        _toast('Success', successMessage, isError: false);
      }
      return result;
    } on DioException catch (e) {
      final (title, msg, unauthorized) = _describeDioError(e);
      _toast(title, msg, isError: true);
      if (unauthorized && onUnauthorized != null) {
        onUnauthorized();
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AuthGuard] Unexpected error: $e\n$st');
      }
      _toast('Error', 'Something went wrong. Please try again.', isError: true);
    }
    return null;
  }

  /// Convert DioException to a user-friendly (title, message, unauthorized?)
  (String, String, bool) _describeDioError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    final msgFromBody = _extractMessage(data);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return (
          'Network timeout',
          'Connection is slow. Please try again.',
          false
        );
      case DioExceptionType.badCertificate:
        return ('Security issue', 'Invalid SSL certificate.', false);
      case DioExceptionType.cancel:
        return ('Cancelled', 'Request was cancelled.', false);
      case DioExceptionType.connectionError:
        return ('Network error', 'Check your internet connection.', false);
      case DioExceptionType.unknown:
      case DioExceptionType.badResponse:
        if (code == 401) {
          return ('Session expired', 'Please sign in again.', true);
        }
        if (code == 403) {
          return (
            'Not allowed',
            msgFromBody ?? 'You don’t have permission.',
            false
          );
        }
        if (code == 404) {
          return ('Not found', msgFromBody ?? 'Resource not found.', false);
        }
        if (code == 409) {
          return (
            'Conflict',
            msgFromBody ?? 'Duplicate or conflicting request.',
            false
          );
        }
        if (code == 422) {
          return (
            'Validation error',
            msgFromBody ?? 'Please check your input.',
            false
          );
        }
        if (code == 429) {
          return ('Slow down', 'Too many requests. Try again shortly.', false);
        }
        if (code != null && code >= 500) {
          return (
            'Server error',
            'We’re fixing an issue. Please try later.',
            false
          );
        }
        // Fallback (show server message if any)
        final body = msgFromBody ?? e.message ?? 'Unexpected error.';
        return ('Error', body, false);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) return data['detail'] as String;
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] is String) return data['error'] as String;
      // Common DRF error structure: {'field': ['msg']}
      final buf = StringBuffer();
      data.forEach((k, v) {
        if (v is List && v.isNotEmpty) {
          buf.writeln('$k: ${v.first}');
        } else if (v is String) {
          buf.writeln('$k: $v');
        }
      });
      final s = buf.toString().trim();
      if (s.isNotEmpty) return s;
    } else if (data is String) {
      return data;
    }
    return null;
  }

  void _toast(String title, String message, {required bool isError}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
      backgroundColor: isError ? const GetSnackBar().backgroundColor : null,
      colorText: null,
      isDismissible: true,
    );
  }
}
