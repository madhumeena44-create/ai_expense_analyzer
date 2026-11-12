import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device has biometric hardware or screen lock available
  static Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException catch (e) {
      print('Error checking biometric support: $e');
      return false;
    }
  }

  /// Trigger the native fingerprint / face / PIN prompt
  static Future<bool> authenticate() async {
    try {
      final bool isAvailable = await canAuthenticate();
      if (!isAvailable) {
        // Device does not have biometric hardware or security set up, allow entry
        return true;
      }

      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access AI Expense Analyzer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Falls back to device PIN/Pattern if fingerprint fails
        ),
      );
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }
}