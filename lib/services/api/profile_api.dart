// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';

import 'api_paths.dart';
import 'core_client.dart';

class ProfileApiError implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ProfileApiError(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ProfileApiError($statusCode): $message';
}

class ProfileApi {
  ProfileApi._(this._dio);

  static ProfileApi? _instance;
  final Dio _dio;

  static Future<ProfileApi> ensureInitialized() async {
    await CoreClient.ensure();
    _instance ??= ProfileApi._(CoreClient.I.dio);
    return _instance!;
  }

  static ProfileApi get I =>
      _instance ??
      (throw StateError('ProfileApi not initialized. Call ensureInitialized().'));

  ProfileApiError _errFromDio(
    DioException e, {
    String fallback = 'Request failed',
  }) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String msg = fallback;

    try {
      if (data is Map) {
        final m = data.cast<String, dynamic>();
        msg = (m['detail'] ?? m['error'] ?? m['message'] ?? fallback).toString();

        if (msg == fallback && m.isNotEmpty) {
          final firstKey = m.keys.first;
          final v = m[firstKey];
          if (v is List && v.isNotEmpty) {
            msg = v.first.toString();
          } else {
            msg = v.toString();
          }
        }
      } else if (data is String && data.trim().isNotEmpty) {
        msg = data;
      }
    } catch (_) {}

    return ProfileApiError(msg, statusCode: code, data: data);
  }

  Map<String, dynamic> _mapOrThrow(dynamic data, Response res) {
    if (data is Map) return data.cast<String, dynamic>();
    throw ProfileApiError(
      'Unexpected response from server',
      statusCode: res.statusCode,
      data: data,
    );
  }

  // Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final res = await _dio.get(ApiPaths.profileMe);
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to load profile');
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async {
    patch.remove('email'); // do not allow email changes from UI
    try {
      final res = await _dio.patch(ApiPaths.profileUpdate, data: patch);
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to update profile');
    }
  }

  Future<Map<String, dynamic>> updateLimits({
    required String dailyLimit,
    required String monthlyLimit,
  }) async {
    try {
      final res = await _dio.patch(
        ApiPaths.profileLimits,
        data: {
          'daily_limit': dailyLimit,
          'monthly_limit': monthlyLimit,
        },
      );
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to update limits');
    }
  }

  Future<Map<String, dynamic>> requestCloseAccount({
    required String reason,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        ApiPaths.profileCloseAccount,
        data: {
          'reason': reason,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to submit close-account request');
    }
  }

  Future<Map<String, dynamic>> submitKycIdentifiers({
    required String country,
    String? idType,
    String? idNumber,
    String? bvn,
    String? nin,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiPaths.kycIdentifiers,
        data: {
          'country': country,
          if (idType != null) 'id_type': idType,
          if (idNumber != null) 'id_number': idNumber,
          if (bvn != null) 'bvn': bvn,
          if (nin != null) 'nin': nin,
          if (phone != null) 'phone': phone,
        },
      );
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to submit identifiers');
    }
  }

  Future<Map<String, dynamic>> uploadKycDoc({
    required String documentType,
    required File file,
  }) async {
    final form = FormData.fromMap({
      'document_type': documentType,
      'file': await MultipartFile.fromFile(file.path),
    });

    try {
      final res = await _dio.post(
        ApiPaths.kycDocumentUpload,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _mapOrThrow(res.data, res);
    } on DioException catch (e) {
      throw _errFromDio(e, fallback: 'Failed to upload document');
    }
  }
}
