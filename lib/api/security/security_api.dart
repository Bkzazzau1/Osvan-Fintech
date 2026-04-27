// lib/api/security/security_api.dart
import 'package:dio/dio.dart';
// Prefix imports to avoid symbol collisions.
import 'package:osvan_app/services/api/api_paths.dart' as paths;

class SecurityApi {
  final Dio _dio;

  // Require a configured Dio (e.g., from your ApiClient singleton/factory).
  SecurityApi({required Dio dio}) : _dio = dio;

  /// GET /api/security/pin/status/
  /// -> { "status": true, "data": { "hasPin": true/false } }
  Future<bool> hasPin() async {
    final resp = await _dio.get(paths.ApiPaths.securityPinStatus);

    final body = resp.data;
    if (body is Map) {
      final data = (body['data'] is Map) ? (body['data'] as Map) : null;
      return data?['hasPin'] == true;
    }
    return false;
  }

  /// POST /api/security/pin/set/
  /// body: { "pin": "1234" }
  Future<void> setPin(String pin) async {
    final resp = await _dio.post(
      paths.ApiPaths.securitySetPin,
      data: {"pin": pin},
    );

    if (!_isSuccess(resp)) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: _pickMessage(resp.data) ?? "Failed to set PIN",
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// POST /api/security/pin/change/
  /// body: { "oldPin": "1234", "newPin": "5678" }
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final resp = await _dio.post(
      paths.ApiPaths.securityChangePin,
      data: {"oldPin": oldPin, "newPin": newPin},
    );

    if (!_isSuccess(resp)) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: _pickMessage(resp.data) ?? "Failed to change PIN",
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// POST /api/security/pin/verify/
  /// body: { "pin": "1234" }
  Future<void> verifyPin(String pin) async {
    final resp = await _dio.post(
      paths.ApiPaths.securityVerifyPin,
      data: {"pin": pin},
    );

    if (!_isSuccess(resp)) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: _pickMessage(resp.data) ?? "Failed to verify PIN",
        type: DioExceptionType.badResponse,
      );
    }
  }

  bool _isSuccess(Response resp) {
    final code = resp.statusCode ?? 0;
    if (code >= 200 && code < 300) return true;
    final data = resp.data;
    if (data is Map) {
      final status = data['status'] ?? data['success'] ?? data['ok'];
      if (status == true) return true;
    }
    return false;
  }

  String? _pickMessage(dynamic data) {
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['error'] is String) return data['error'] as String;
      if (data['error'] is Map && data['error']['code'] is String) {
        return data['error']['code'] as String;
      }
    }
    return null;
  }
}
