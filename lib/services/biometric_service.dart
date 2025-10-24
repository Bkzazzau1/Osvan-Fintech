import 'dart:developer';

import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // ✅ Check if biometrics are supported and available
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e, stack) {
      log(
        'Error checking biometric availability',
        name: 'BiometricService',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// ✅ Authenticate user using PIN or biometrics depending on user's choice
  static Future<bool> authenticateUser({bool useBiometrics = true}) async {
    try {
      final available = await isBiometricAvailable();

      if (!useBiometrics || !available) {
        log(
          'Biometric not used or unavailable. Fallback to PIN.',
          name: 'BiometricService',
        );
        return true; // ✅ Allow PIN fallback
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } catch (e, stackTrace) {
      log(
        'Biometric authentication failed',
        name: 'BiometricService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
