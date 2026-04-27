// lib/controller/security_controller.dart
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../api/security/security_api.dart';

class SecurityController extends GetxController {
  final SecurityApi api;
  SecurityController({required this.api});

  final isSubmitting = false.obs;
  final error = RxnString();
  final success = RxnString();

  Future<bool> setPin(String pin) async {
    isSubmitting.value = true;
    error.value = null;
    success.value = null;
    try {
      await api.setPin(pin);
      success.value = "Transaction PIN set";
      return true;
    } on DioException catch (e) {
      error.value = _extractErr(e) ?? "Failed to set PIN";
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    isSubmitting.value = true;
    error.value = null;
    success.value = null;
    try {
      await api.changePin(oldPin: oldPin, newPin: newPin);
      success.value = "Transaction PIN changed";
      return true;
    } on DioException catch (e) {
      error.value = _extractErr(e) ?? "Failed to change PIN";
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  String? _extractErr(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data["message"] is String) return data["message"];
      if (data is Map &&
          data["error"] is Map &&
          data["error"]["code"] is String) {
        return data["error"]["code"];
      }
    } catch (_) {}
    return null;
  }
}
