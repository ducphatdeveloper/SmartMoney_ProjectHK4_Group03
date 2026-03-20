import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:io' show Platform; // Chỉ import Platform từ dart:io
import 'package:flutter/foundation.dart'; // Import for kIsWeb

import '../../../core/di/setup_dependencies.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/helpers/token_helper.dart';
import '../models/login_request.dart';
import '../models/auth_response.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  // Constructor: Tải thông tin user nếu đã đăng nhập trước đó
  AuthProvider() {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    final accessToken = await TokenHelper.getAccessToken();
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      // Lấy thông tin cơ bản từ JWT
      final decodedToken = JwtDecoder.decode(accessToken);
      _currentUser = UserModel(
        userId: decodedToken['accId'], // Giả định accId có trong token
        accEmail: decodedToken['sub'], // Giả định email là subject
        // Các thông tin khác có thể lấy từ token nếu có
        // hoặc gọi API /users/profile
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceToken; // FCM token
      String? deviceType;
      String? deviceName;

      if (kIsWeb) {
        deviceType = "WEB";
        deviceName = "Web Browser"; // Hoặc có thể lấy thông tin chi tiết hơn từ trình duyệt nếu cần
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceType = "ANDROID";
        deviceName = androidInfo.model;
        // deviceToken = await FirebaseMessaging.instance.getToken(); // Uncomment if Firebase is set up
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceType = "IOS";
        deviceName = iosInfo.name;
        // deviceToken = await FirebaseMessaging.instance.getToken(); // Uncomment if Firebase is set up
      } else {
        // Các nền tảng desktop khác (Windows, macOS, Linux)
        deviceType = Platform.operatingSystem.toUpperCase();
        deviceName = Platform.localHostname;
      }

      final request = LoginRequest(
        username: username,
        password: password,
        deviceToken: deviceToken,
        deviceType: deviceType,
        deviceName: deviceName,
      );

      final response = await _authService.login(request);

      if (response.success && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    // Lấy deviceToken để gửi lên server khi logout
    String? deviceToken;
    // if (Firebase.apps.isNotEmpty) { // Check if Firebase is initialized
    //   deviceToken = await FirebaseMessaging.instance.getToken();
    // }

    await _authService.logout(deviceToken: deviceToken ?? ""); // Gửi rỗng nếu không có

    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
