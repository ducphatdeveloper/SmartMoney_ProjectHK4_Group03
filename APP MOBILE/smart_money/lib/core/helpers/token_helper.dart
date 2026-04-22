
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import '../constants/app_constants.dart';

class TokenHelper {

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Lưu Access Token và Refresh Token
  static Future<void> saveTokens(
      String accessToken,
      String refreshToken
      ) async {

    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: accessToken,
    );

    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
    debugPrint("TokenHelper: Tokens saved.");
  }

  /// Lấy Access Token
  static Future<String?> getAccessToken() async {
    final token = await _storage.read(
      key: AppConstants.accessTokenKey,
    );
    debugPrint("TokenHelper: Access Token retrieved: ${token != null ? 'Exists' : 'Null'}");
    return token;
  }

  /// Lấy Refresh Token
  static Future<String?> getRefreshToken() async {
    final token = await _storage.read(
      key: AppConstants.refreshTokenKey,
    );
    debugPrint("TokenHelper: Refresh Token retrieved: ${token != null ? 'Exists' : 'Null'}");
    return token;
  }

  /// Xóa token khi logout
  static Future<void> clearTokens() async {
    await _storage.delete(
      key: AppConstants.accessTokenKey,
    );
    await _storage.delete(
      key: AppConstants.refreshTokenKey,
    );
    debugPrint("TokenHelper: Tokens cleared.");
  }

  // =============================================
  // BIOMETRIC & CREDENTIALS HELPERS
  // =============================================

  /// Lưu trạng thái bật/tắt sinh trắc học
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.biometricEnabledKey,
      value: enabled.toString(),
    );
    debugPrint("TokenHelper: Biometric Enabled set to $enabled.");
  }

  /// Lưu thông tin đăng nhập để dùng cho sinh trắc học
  static Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: 'bio_username', value: username);
    await _storage.write(key: 'bio_password', value: password);
    debugPrint("TokenHelper: Credentials saved for biometric login (username: $username).");
  }

  /// Lấy thông tin đăng nhập đã lưu
  static Future<Map<String, String?>> getCredentials() async {
    String? u = await _storage.read(key: 'bio_username');
    String? p = await _storage.read(key: 'bio_password');
    debugPrint("TokenHelper: Credentials retrieved for biometric login (username: ${u != null ? 'Exists' : 'Null'}).");
    return {'username': u, 'password': p};
  }

  /// Kiểm tra xem sinh trắc học có đang bật không
  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: AppConstants.biometricEnabledKey);
    debugPrint("TokenHelper: isBiometricEnabled check: ${value == 'true'}.");
    return value == 'true';
  }

  /// Xóa cấu hình sinh trắc học và thông tin lưu trữ
  static Future<void> clearBiometricConfig() async {
    await _storage.delete(key: AppConstants.biometricEnabledKey);
    await _storage.delete(key: 'bio_username');
    await _storage.delete(key: 'bio_password');
    debugPrint("TokenHelper: Biometric config and credentials cleared.");
  }
}
