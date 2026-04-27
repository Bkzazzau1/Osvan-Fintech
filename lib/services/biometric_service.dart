import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static String? lastErrorMessage;

  /// True only if device supports biometrics AND the user has enrolled at least one.
  static Future<bool> isBiometricReady() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e, stack) {
      log(
        'Error checking biometric readiness',
        name: 'BiometricService',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Authenticate with biometrics only. Returns false if unavailable/cancelled/failed.
  static Future<bool> authenticateBiometric() async {
    try {
      lastErrorMessage = null;
      final ready = await isBiometricReady();
      if (!ready) {
        lastErrorMessage =
            'Fingerprint/Face ID not available or not enrolled on this device.';
        return false;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirm it is you to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (!ok) {
        lastErrorMessage = 'Authentication failed or was cancelled.';
      }
      return ok;
    } on PlatformException catch (e, stackTrace) {
      log(
        'Biometric authentication failed',
        name: 'BiometricService',
        error: e,
        stackTrace: stackTrace,
      );
      lastErrorMessage = _mapPlatformError(e);
      return false;
    } catch (e, stackTrace) {
      log(
        'Biometric authentication failed',
        name: 'BiometricService',
        error: e,
        stackTrace: stackTrace,
      );
      lastErrorMessage = 'Authentication failed. Please try again.';
      return false;
    }
  }

  static String _mapPlatformError(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return 'No fingerprint/Face ID enrolled on this device.';
      case auth_error.lockedOut:
      case auth_error.permanentlyLockedOut:
        return 'Too many failed attempts. Try again later or use device passcode.';
      case auth_error.notAvailable:
        return 'Biometric hardware not available.';
      case auth_error.passcodeNotSet:
        return 'Device passcode is not set. Please set it first.';
      default:
        // Fallback string matches for platforms that return plain strings
        const cancelledCodes = {
          'CanceledByUser',
          'CanceledBySystem',
          'userCancel',
          'systemCancel',
          'appCancel',
          'userFallback',
        };
        if (cancelledCodes.contains(e.code)) {
          return 'Authentication cancelled.';
        }
        return e.message ?? 'Authentication failed.';
    }
  }
}
