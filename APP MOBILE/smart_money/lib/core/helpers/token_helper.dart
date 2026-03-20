
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  }

  /// Lấy Access Token
  static Future<String?> getAccessToken() async {
    return await _storage.read(
      key: AppConstants.accessTokenKey,
    );
  }

  /// Lấy Refresh Token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: AppConstants.refreshTokenKey,
    );
  }

  /// Xóa token khi logout
  static Future<void> clearTokens() async {

    await _storage.delete(
      key: AppConstants.accessTokenKey,
    );

    await _storage.delete(
      key: AppConstants.refreshTokenKey,
    );
  }

}
