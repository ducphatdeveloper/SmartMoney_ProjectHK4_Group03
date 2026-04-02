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
import '../models/register_request.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get userEmail => _currentUser?.accEmail;

  // Constructor: Tải thông tin user nếu đã đăng nhập trước đó
  AuthProvider() {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    final accessToken = await TokenHelper.getAccessToken();
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      // Giải mã token để lấy các trường (theo JwtUtils của Spring Boot)
      // { "userId": 6, "sub": "minh.pham@gmail.com", "authorities": ["ROLE_USER", "USER_STANDARD_MANAGE"] }
      final decodedToken = JwtDecoder.decode(accessToken);
      
      // Parse authorities thành roleCode và permissions
      List<dynamic> authorities = decodedToken['authorities'] ?? [];
      String? roleCode;
      List<String> permissions = [];
      
      for (var auth in authorities) {
        if (auth.toString().startsWith('ROLE_')) {
          roleCode = auth.toString();
        } else {
          permissions.add(auth.toString());
        }
      }

      // Tái tạo lại UserModel ở mức cơ bản từ JWT
      // Lưu ý: Các field như avatarUrl, currency sẽ null cho đến khi gọi API /users/profile
      _currentUser = UserModel(
        userId: decodedToken['userId'],
        accEmail: decodedToken['sub'].contains('@') ? decodedToken['sub'] : null,
        accPhone: !decodedToken['sub'].contains('@') ? decodedToken['sub'] : null,
        roleCode: roleCode,
        permissions: permissions,
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
        deviceName = "Web Browser";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceType = "ANDROID";
        deviceName = androidInfo.model;
        // deviceToken = await FirebaseMessaging.instance.getToken();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceType = "IOS";
        deviceName = iosInfo.name;
        // deviceToken = await FirebaseMessaging.instance.getToken();
      } else {
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
        // Có đầy đủ data từ API
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

  Future<bool> register(String? email, String? phone, String password, String confirmPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final request = RegisterRequest(
        accEmail: email,
        accPhone: phone,
        password: password,
        confirmPassword: confirmPassword,
      );

      final response = await _authService.register(request);

      if (response.success) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    String? deviceToken;
    // if (Firebase.apps.isNotEmpty) {
    //   deviceToken = await FirebaseMessaging.instance.getToken();
    // }

    await _authService.logout(deviceToken: deviceToken ?? "");

    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Yêu cầu gửi mã OTP đặt lại mật khẩu qua Email (Alias cho requestPasswordReset)
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.forgotPassword(email);
      
      _isLoading = false;
      notifyListeners();
      return response.success;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Xác nhận OTP và đặt mật khẩu mới
  Future<bool> confirmResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.resetPassword(email, otp, newPassword);

      _isLoading = false;
      notifyListeners();
      return response.success;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật ảnh đại diện
  Future<String?> updateAvatar(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.updateAvatar(filePath);
      
      if (response.success && response.data != null) {
        // Cập nhật lại state local
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(avatarUrl: response.data);
        }
        _isLoading = false;
        notifyListeners();
        return response.data; // Trả về avatarUrl mới
      } else {
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
