import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../helpers/token_helper.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Thực hiện quét sinh trắc học
  Future<bool> authenticate({String? customMessage}) async {
    try {
      bool isEnabled = await TokenHelper.isBiometricEnabled();
      if (!isEnabled) return false;

      // Sử dụng cấu hình cơ bản để tương thích tốt nhất với mọi phiên bản local_auth
      return await _auth.authenticate(
        localizedReason: customMessage ?? 'Xác thực để đăng nhập vào SmartMoney',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Quan trọng: Cho phép FaceID AI trên Android
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print("Lỗi xác thực sinh trắc học: $e");
      return false;
    } catch (e) {
      return false;
    }
  }
}
