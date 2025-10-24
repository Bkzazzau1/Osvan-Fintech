// lib/screen/transaction/services/transactions_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:osvan_app/services/api_client.dart';

import '../models/transaction.dart';

class TransactionsService {
  TransactionsService._();
  static final TransactionsService instance = TransactionsService._();

  /// DRF canonical path exposed by backend (no /v1 prefix in current spec).
  /// Keep paths centralized in ApiPaths.
  static String get _path => ApiPaths.transactions; // '/api/transactions/'

  /// Fetch a page of transactions with safe pagination handling.
  ///
  /// [include]: 'all' | 'fiat' | 'crypto'
  /// [order]:   'asc' | 'desc'
  Future<List<Txn>> fetchPage({
    required int page,
    required int pageSize,
    String? walletId,
    String include = 'all',
    String order = 'desc',
  }) async {
    final api = await ApiClient.ensureInitialized();
    final Dio dio = api.dio;

    // Prefer DRF-style pagination; send offset/limit as harmless fallback.
    final qp = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'offset': (page - 1) * pageSize,
      'limit': pageSize,
      'include': include,
      'order': order,
      if (walletId != null && walletId.isNotEmpty) 'wallet': walletId,
    };

    try {
      final res = await dio.get(_path, queryParameters: qp);
      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Txn.fromJson)
            .toList();
      }

      if (data is Map<String, dynamic>) {
        final results = (data['results'] as List?) ?? const [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(Txn.fromJson)
            .toList();
      }

      throw StateError('Unexpected transactions response: ${data.runtimeType}');
    } on DioException catch (e) {
      final dynamic body = e.response?.data;
      final msg = body is Map
          ? (body['detail']?.toString() ??
              body['message']?.toString() ??
              e.message)
          : e.message;

      if (kDebugMode) {
        // ignore: avoid_print
        print('TransactionsService.fetchPage DioException: $msg');
      }
      throw Exception(msg ?? 'Failed to load transactions');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('TransactionsService.fetchPage error: $e');
      }
      throw Exception('Failed to load transactions');
    }
  }
}
