import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'auth_storage.dart';

class ApiClient {
  final Dio _dio;
  final AuthStorage _auth;
  final String baseUrl;

  ApiClient({
    required this.baseUrl,
    Dio? dio,
    AuthStorage? auth,
  })  : _dio = dio ?? Dio(),
        _auth = auth ?? AuthStorage() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Attach JWT
        final access = await _auth.getAccess();
        if (access != null && access.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $access';
        }

        // Observability & idempotency
        options.headers['x-request-id'] ??= const Uuid().v4();
        options.headers['Idempotency-Key'] ??= const Uuid().v4();
        options.headers['x-client-version'] = 'osvan-flutter/1.0.0';

        return handler.next(options);
      },
      onError: (err, handler) async {
        // Try JWT refresh on 401 once
        if (err.response?.statusCode == 401) {
          final retried = await _tryRefreshAndRetry(err.requestOptions);
          if (retried != null) return handler.resolve(retried);
        }
        return handler.next(err);
      },
    ));
  }

  Future<Response<dynamic>?> _tryRefreshAndRetry(RequestOptions failed) async {
    try {
      final refresh = await _auth.getRefresh();
      if (refresh == null || refresh.isEmpty) return null;

      // Hit our Django custom refresh endpoint
      final r = await _dio.post(
        '/auth/refresh/',
        data: {'refresh': refresh},
        options: Options(headers: {'x-skip-auth': '1'}),
      );
      final access = r.data['access'] as String?;
      final newRefresh = r.data['refresh'] as String? ?? refresh;
      if (access == null) return null;

      await _auth.saveTokens(access: access, refresh: newRefresh);

      // Clone the failed request with new token
      final opts = Options(
        method: failed.method,
        headers: Map<String, dynamic>.from(failed.headers)
          ..['Authorization'] = 'Bearer $access',
      );

      return _dio.request<dynamic>(
        failed.path,
        data: failed.data,
        queryParameters: failed.queryParameters,
        options: opts,
      );
    } catch (_) {
      return null;
    }
  }

  Dio get raw => _dio;
}
