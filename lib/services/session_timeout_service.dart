import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:osvan_app/store/session_store.dart';

/// Global session timeout handler.
/// - Logs out after [idleTimeout] of no user input (tap/scroll).
/// - Logs out after [hardTimeout] regardless of activity.
class SessionTimeoutService {
  SessionTimeoutService._();
  static final SessionTimeoutService instance = SessionTimeoutService._();

  /// Disable idle/hard auto-logout; rely on token expiry instead.
  bool enabled = false;

  Duration idleTimeout = const Duration(minutes: 5);
  Duration hardTimeout = const Duration(minutes: 10);

  Timer? _idleTimer;
  Timer? _hardTimer;
  bool _started = false;
  bool _bound = false;

  /// Start timers if logged in. Safe to call repeatedly.
  Future<void> start() async {
    if (!enabled) return;
    if (_started) return;
    await SessionStore.init();
    if (!await SessionStore.instance.isLoggedIn) return;

    _started = true;
    _bindActivity();
    _resetIdle();
    _resetHard();
  }

  /// Stop timers and unbind listeners.
  void stop() {
    _started = false;
    _idleTimer?.cancel();
    _hardTimer?.cancel();
    _idleTimer = null;
    _hardTimer = null;
    _unbindActivity();
  }

  void _bindActivity() {
    if (!enabled || _bound) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    _bound = true;
  }

  void _unbindActivity() {
    if (!_bound) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    _bound = false;
  }

  void _onPointerEvent(PointerEvent _) {
    if (!enabled || !_started) return;
    _resetIdle();
  }

  void _resetIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _forceLogout);
  }

  void _resetHard() {
    _hardTimer?.cancel();
    _hardTimer = Timer(hardTimeout, _forceLogout);
  }

  Future<void> _forceLogout() async {
    stop();
    try {
      await SessionStore.instance.clear();
    } catch (_) {}
    if (Get.currentRoute != '/login') {
      Get.snackbar(
        'Session expired',
        'Please sign in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAllNamed('/login');
    }
  }
}
