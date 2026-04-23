import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:local_auth_android/local_auth_android.dart';
import '../helpers/token_helper.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device hardware supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Check if the user has enrolled (setup) any biometrics on the device
  Future<bool> isBiometricEnrolled() async {
    try {
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Perform biometric authentication
  Future<bool> authenticate({String? customMessage}) async {
    try {
      bool isEnabled = await TokenHelper.isBiometricEnabled();
      if (!isEnabled) return false;

      return await _auth.authenticate(
        localizedReason: customMessage ?? 'Please authenticate to continue',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            biometricHint: 'Scan fingerprint',
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') {
        // User has not set up biometrics on the device
        print("Biometrics not enrolled");
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
