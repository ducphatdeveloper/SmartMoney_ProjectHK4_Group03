import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:local_auth_android/local_auth_android.dart';
import '../helpers/token_helper.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Kiểm tra phần cứng thiết bị có hỗ trợ sinh trắc học không
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra xem người dùng đã đăng ký (setup) vân tay/khuôn mặt trong máy chưa
  Future<bool> isBiometricEnrolled() async {
    try {
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Lấy danh sách các loại sinh trắc học khả dụng
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

      return await _auth.authenticate(
        localizedReason: customMessage ?? 'Vui lòng xác thực để tiếp tục',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Xác thực sinh trắc học',
            biometricHint: 'Quét khuôn mặt hoặc vân tay',
            cancelButton: 'Hủy',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') {
        // Người dùng chưa cài đặt sinh trắc học trong máy
        print("Chưa đăng ký sinh trắc học");
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
