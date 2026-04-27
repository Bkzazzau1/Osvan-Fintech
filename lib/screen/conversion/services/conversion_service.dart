import 'package:dio/dio.dart';
import 'package:osvan_app/services/api/api_paths.dart';
import 'package:osvan_app/services/api/core_client.dart';

import '../models/conversion_models.dart';

class ConversionService {
  final Dio _dio;
  ConversionService({Dio? dio}) : _dio = dio ?? CoreClient.I.dio;

  Future<ConversionQuote> quote({
    required String from,
    required String to,
    String? network,
    required String amount, // major units string e.g. "1500.00"
  }) async {
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      'amount': amount,
      if (network != null && network.isNotEmpty) 'network': network,
    };
    final res = await _dio.post(ApiPaths.convertQuote, data: payload);
    return ConversionQuote.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns server response (ok, timestamp, credited, etc.)
  Future<Map<String, dynamic>> confirm({
    required String from,
    required String to,
    String? network,
    required String amount, // major units
    String? idempotencyKey,
    bool debug = false,
    String? quoteId,
    String? expectedReceive,
    String? reference,
  }) async {
    final payload = <String, dynamic>{
      'from': from,
      'to': to,
      'amount': amount,
      if (network != null && network.isNotEmpty) 'network': network,
      if (quoteId != null && quoteId.isNotEmpty) 'quoteId': quoteId,
      if (quoteId != null && quoteId.isNotEmpty) 'quote_id': quoteId,
      if (expectedReceive != null && expectedReceive.isNotEmpty)
        'expectedReceive': expectedReceive,
      if (expectedReceive != null && expectedReceive.isNotEmpty)
        'expected_receive': expectedReceive,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    };

    final headers = <String, dynamic>{};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    if (debug) headers['X-Debug'] = '1';

    final res = await _dio.post(
      ApiPaths.convertConfirm,
      data: payload,
      options: Options(headers: headers.isEmpty ? null : headers),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)));
    }
    return <String, dynamic>{};
  }
}
