import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/services/auth_service.dart';
import 'package:osvan_app/services/notification_service.dart';
import 'package:osvan_app/services/session_timeout_service.dart';
import 'package:osvan_app/store/session_store.dart';

class AuthController extends GetxController {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final isLoading = false.obs;
  final errorText = RxnString();

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  Future<void> init() async {
    await SessionStore.init();
  }

  String _msgFromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // Try DRF style: {"detail": "..."}
    if (data is Map && data['detail'] != null) {
      final m = data['detail'].toString().trim();
      if (m.isNotEmpty) return m;
    }

    // Try field errors: {"password":["..."]} / {"username":["..."]}
    if (data is Map) {
      for (final k in ['password', 'username', 'email', 'non_field_errors']) {
        final v = data[k];
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }

    // Friendly defaults
    if (status == 401) return 'Wrong email or password.';
    if (status == 403) return 'Account disabled.';
    if (status == 400) return 'Invalid login details.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Network timeout. Try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Network error. Check your internet.';
    }

    return 'Login failed. Please try again.';
  }

  Future<void> login() async {
    if (isLoading.value) return;

    errorText.value = null;
    isLoading.value = true;

    try {
      final email = emailCtrl.text.trim();
      final password = passwordCtrl.text;

      final result = await AuthService.login(
        email: email,
        password: password,
        username: '', // email-first login
      );

      // ✅ GUARANTEED FAIL-FAST:
      // If backend returns {"detail": "..."} treat it as an error immediately.
      final detail = result['detail']?.toString().trim();
      if (detail != null && detail.isNotEmpty) {
        throw Exception(detail);
      }

      final access =
          (result['access'] ?? result['token'] ?? result['access_token'])
              ?.toString();
      final refresh =
          (result['refresh'] ?? result['refresh_token'])?.toString();

      if (access == null || access.isEmpty) {
        throw Exception('Login response missing access token');
      }

      await SessionStore.instance.saveTokens(access: access, refresh: refresh);

      // Kick off wallet refresh loop (immediate + 1s + every 60s)
      try {
        unawaited(Get.find<WalletsController>().startAutoRefresh());
      } catch (_) {}

      // Start session timeout timers (idle + hard)
      try {
        await SessionTimeoutService.instance.start();
      } catch (_) {}

      // Register device for push notifications (best-effort)
      try {
        unawaited(NotificationService.instance.initAndRegister());
      } catch (_) {}

      Get.offAllNamed('/main');

      Get.snackbar(
        'Login Successful',
        'Welcome back',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on DioException catch (e) {
      final msg = _msgFromDio(e);
      errorText.value = msg;
      throw Exception(msg);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      errorText.value = msg.isEmpty ? 'Login failed' : msg;
      throw Exception(errorText.value ?? 'Login failed');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout({bool notifyServer = true}) async {
    try {
      await AuthService.logout(notifyServer: notifyServer);
    } finally {
      try {
        await NotificationService.instance.unregister();
      } catch (_) {}
      try {
        await NotificationService.instance.dispose();
      } catch (_) {}
      try {
        Get.find<WalletsController>().stopAutoRefresh(clearState: true);
      } catch (_) {}
      try {
        SessionTimeoutService.instance.stop();
      } catch (_) {}
      await SessionStore.instance.clear();
      Get.offAllNamed('/login');
    }
  }
}
