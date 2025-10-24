// lib/features/wallets/services/collections_service.dart
import 'package:dio/dio.dart';
import 'package:osvan_app/services/api_client.dart';

class CollectionsService {
  CollectionsService();

  static String _countryToCode(String country) {
    final c = country.trim().toLowerCase();
    if (c == 'nigeria' || c == 'ng' || c == 'ngn') return 'NG';
    if (c == 'kenya' || c == 'ke' || c == 'kes') return 'KE';
    if (c == 'uganda' || c == 'ug' || c == 'ugx') return 'UG';
    // default: pass-through but uppercase short codes
    return country.length <= 3 ? country.toUpperCase() : country;
  }

  Future<Map<String, String>> getDetails({
    required String country,
    String? method, // 'momo' or 'bank' (optional)
  }) async {
    final api = await ApiClient.ensureInitialized();
    final code = _countryToCode(country);
    final normalizedMethod = method?.toLowerCase();

    try {
      final data = await api.getCollectionDetails(
        country: code,
        method: normalizedMethod,
      );

      // If backend already returns a flat map (preferred)
      // e.g. {"Provider":"M-Pesa","Paybill":"123456","Reference":"OSVAN-..."}
      if (!data.containsKey('status') && !data.containsKey('receiver_value')) {
        return data.map((k, v) => MapEntry(k, '${v ?? ''}'));
      }

      // Otherwise, support the documented shape:
      // { status: "available", receiver_value: "...", provider: "...", reference: "..." }
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'available') {
        return {
          'Receiver': (data['receiver_value'] ?? '').toString(),
          'Provider': (data['provider'] ?? '').toString(),
          'Reference': (data['reference'] ?? '').toString(),
        };
      }

      final msg = (data['message'] ?? 'Not supported yet').toString();
      throw DioException(
        requestOptions:
            RequestOptions(path: '/api/v1/wallets/collection-details/'),
        message: msg,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions:
            RequestOptions(path: '/api/v1/wallets/collection-details/'),
        message: e.toString(),
        type: DioExceptionType.unknown,
      );
    }
  }
}
