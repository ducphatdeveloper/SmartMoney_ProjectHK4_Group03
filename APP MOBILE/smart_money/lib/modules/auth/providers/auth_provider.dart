import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/setup_dependencies.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/helpers/token_helper.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/update_profile_request.dart';
import '../../notification/providers/notification_provider.dart';
import 'package:provider/provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();
  UserModel? _currentUser;
  UserModel? _user;

  UserModel? get user => _user;

  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  Map<String, String> _fieldErrors = {};
  Map<String, String> get fieldErrors => _fieldErrors;

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
      final decodedToken = JwtDecoder.decode(accessToken);
      
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

      _currentUser = UserModel(
        userId: decodedToken['userId'],
        accEmail: sub.contains('@') ? sub : null,
        accPhone: !sub.contains('@') ? sub : null,
        roleCode: roleCode,
        permissions: permissions,
      );
    }

    _setLoading(false);
  }

  Future<bool> login(String username, String password, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceToken;
      String? deviceType;
      String? deviceName;

      if (kIsWeb) {
        deviceType = "WEB";
        deviceName = "Web Browser";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceType = "ANDROID";
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceType = "IOS";
        deviceName = iosInfo.name;
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
        _currentUser = UserModel.fromAuthResponse(response.data!);
        _successMessage = response.message ?? 'Đăng nhập thành công';
        
        // Tải thông báo ngay khi đăng nhập
        if (context.mounted) {
          context.read<NotificationProvider>().fetchNotifications();
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _currentUser = null;
        _errorMessage = _extractErrorMessage(response);
        try {
          final raw = response.data as dynamic;
          if (raw is Map<String, dynamic> && raw != null && raw.isNotEmpty) {
            _fieldErrors = Map<String, String>.from(raw as Map<String, dynamic>);
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

      final response = await _authService.register(request);

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
            _fieldErrors = Map<String, String>.from(raw as Map<String, dynamic>);
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

  /// Xử lý đăng xuất và điều hướng về login
  Future<void> logout(BuildContext context) async {
    _setLoading(true);

    try {
      String? deviceToken;
      await _authService.logout(deviceToken: deviceToken ?? "");
      
      // Xóa thông báo khi đăng xuất
      if (context.mounted) {
        context.read<NotificationProvider>().clearNotifications();
      }
    } catch (e) {
      debugPrint("Logout Error: $e");
    } finally {
      // 1. Xóa dữ liệu người dùng cục bộ
      _currentUser = null;
      
      // 2. Xóa các token đã lưu
      await TokenHelper.clearTokens();
      
      _setLoading(false);
      
      // 3. Điều hướng về màn hình đăng nhập và xóa toàn bộ stack cũ
      if (context.mounted) {
        context.go("/login");
      }
    }
  }

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

  Future<String?> updateAvatar(String filePath) async {
    _setLoading(true);
    try {
      final response = await _authService.updateAvatar(filePath);
      if (response.success == true && response.data != null) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(avatarUrl: response.data);
        }
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint("UpdateAvatar Error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

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

  String _extractErrorMessage(dynamic response) {
    try {
      final raw = response.data;
      if (raw is Map && raw.isNotEmpty) {
        return raw.values.join('\n');
      }
    } catch (_) {}
    return response.message?.toString().isNotEmpty == true
        ? response.message.toString()
        : 'Có lỗi xảy ra. Vui lòng thử lại.';
  }
}
