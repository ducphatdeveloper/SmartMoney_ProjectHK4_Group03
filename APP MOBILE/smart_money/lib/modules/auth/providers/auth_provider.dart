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
import '../models/update_profile_request.dart';


class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();
  UserModel? _currentUser;
  UserModel? _user;

  // Thêm getter này để fix lỗi "The getter 'user' isn't defined"
  UserModel? get user => _user;

  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  // Thêm 3 biến state mới
  String? _errorMessage;    // lỗi từ backend — Screen đọc để hiện SnackBar đỏ
  String? get errorMessage => _errorMessage;

  String? _successMessage;  // thành công — Screen đọc để hiện SnackBar xanh
  String? get successMessage => _successMessage;

  // Thêm fieldErrors cho lỗi từng ô
  Map<String, String> _fieldErrors = {};
  Map<String, String> get fieldErrors => _fieldErrors;

  // Constructor: Tải thông tin user nếu đã đăng nhập trước đó
  AuthProvider() {
    _loadCurrentUser();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    _setLoading(true);

    final accessToken = await TokenHelper.getAccessToken();
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      // Giải mã token để lấy các trường (theo JwtUtils của Spring Boot)
      // { "userId": 6, "sub": "minh.pham@gmail.com", "authorities": ["ROLE_USER", "USER_STANDARD_MANAGE"] }
      final decodedToken = JwtDecoder.decode(accessToken);
      
      // Parse authorities thành roleCode và permissions
      List<dynamic> authorities = decodedToken['authorities'] ?? [];
      String? roleCode;
      List<String> permissions = [];
      final String sub = decodedToken['sub']?.toString() ?? "";
      
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
        // accEmail: decodedToken['sub'].contains('@') ? decodedToken['sub'] : null,
        // accPhone: !decodedToken['sub'].contains('@') ? decodedToken['sub'] : null,
        accEmail: sub.contains('@') ? sub : null,
        accPhone: !sub.contains('@') ? sub : null,
        roleCode: roleCode,
        permissions: permissions,
      );
    }

    _setLoading(false);
  }

  Future<bool> login(String username, String password) async {
    // Bước 1: Bật loading, xóa thông báo cũ
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _fieldErrors = {};
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

      // Bước 2: Gọi Service (Service trả ApiResponse, không throw)
      final response = await _authService.login(request);

      // Bước 3: Xử lý kết quả
      if (response.success && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        _successMessage = response.message ?? 'Đăng nhập thành công';
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _currentUser = null;
        _errorMessage = _extractErrorMessage(response);
        try {
          final raw = response.data as dynamic;
          if (raw is Map<String, dynamic> && raw != null && raw.isNotEmpty) {
            _fieldErrors = Map<String, String>.from(raw as Map<String, dynamic>); // {"username": "Sai", ...}
          }
        } catch (_) {}
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      _currentUser = null;
      _errorMessage = 'Không thể kết nối đến server. Kiểm tra lại mạng.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String? email, String? phone, String password, String confirmPassword) async {
    // Bước 1: Bật loading, xóa thông báo cũ
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final request = RegisterRequest(
        accEmail: email,
        accPhone: phone,
        password: password,
        confirmPassword: confirmPassword,
      );

      // Bước 2: Gọi Service (Service trả ApiResponse, không throw)
      final response = await _authService.register(request);

      // Bước 3: Xử lý kết quả
      if (response.success) {
        _successMessage = response.message ?? 'Đăng ký thành công';
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = _extractErrorMessage(response);
        try {
          final raw = response.data as dynamic;
          if (raw is Map<String, dynamic> && raw != null && raw.isNotEmpty) {
            _fieldErrors = Map<String, String>.from(raw as Map<String, dynamic>); // {"accEmail": "Sai", ...}
          }
        } catch (_) {}
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("Register Error: $e");
      _errorMessage = 'Không thể kết nối đến server. Kiểm tra lại mạng.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      String? deviceToken;
      await _authService.logout(deviceToken: deviceToken ?? "");
    } catch (e) {
      debugPrint("Logout Error: $e");
    } finally {
      _currentUser = null;
      _setLoading(false);
    }
  }

  /// Yêu cầu gửi mã OTP đặt lại mật khẩu qua Email (Alias cho requestPasswordReset)
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);

    try {
      final response = await _authService.forgotPassword(email);
      return response.success == true;
    } catch (e) {
      debugPrint("RequestPasswordReset Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Xác nhận OTP và đặt mật khẩu mới
  Future<bool> confirmResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _setLoading(true);

    try {
      final response = await _authService.resetPassword(email, otp, newPassword);
      return response.success == true;
    } catch (e) {
      debugPrint("ConfirmResetPassword Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Lấy thông tin hồ sơ chi tiết từ Server
  Future<void> getProfile() async {
    _setLoading(true);
    try {
      final response = await _authService.getProfile();
      if (response.success == true && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
      }
    } catch (e) {
      debugPrint("GetProfile Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Cập nhật ảnh đại diện
  Future<String?> updateAvatar(String filePath) async {
    _setLoading(true);

    try {
      final response = await _authService.updateAvatar(filePath);

      if (response.success == true && response.data != null) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(avatarUrl: response.data);
        }
        return response.data; // Trả về avatarUrl mới
      }
      return null;
    } catch (e) {
      debugPrint("UpdateAvatar Error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cập nhật thông tin hồ sơ
  Future<bool> updateProfile(UpdateProfileRequest request) async {
    _setLoading(true);

    try {
      final response = await _authService.updateProfile(request);

      if (response.success == true && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("UpdateProfile Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Gửi OTP khóa khẩn cấp
  Future<bool> sendEmergencyLockOTP(String identityCard) async {
    _setLoading(true);

    try {
      final response = await _authService.sendEmergencyLockOTP(identityCard);
      return response.success == true;
    } catch (e) {
      debugPrint("EmergencyLock Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Xác nhận và khóa tài khoản
  Future<bool> verifyAndLockAccount(String otpCode) async {
    _setLoading(true);

    try {
      final response = await _authService.verifyAndLockAccount(otpCode);
      return response.success == true;
    } catch (e) {
      debugPrint("VerifyAndLock Error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =============================================
  // [N] HELPER — Đọc lỗi từ response backend
  // =============================================
  // Xử lý 2 dạng lỗi:
  //   • data là Map  → lỗi từng ô (@Valid) → gom thành 1 chuỗi
  //   • data là null → lấy message trực tiếp (IllegalArgumentException...)
  String _extractErrorMessage(dynamic response) {
    try {
      final raw = response.data;
      if (raw is Map && raw.isNotEmpty) {
        return raw.values.join('\n'); // "Số tiền trống\nChưa chọn ví"
      }
    } catch (_) {}
    return response.message?.toString().isNotEmpty == true
        ? response.message.toString()
        : 'Có lỗi xảy ra. Vui lòng thử lại.';
  }
}
