import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/di/setup_dependencies.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/helpers/token_helper.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/update_profile_request.dart';
import '../../notification/providers/notification_provider.dart';
import 'package:provider/provider.dart';

// Enum để biểu thị trạng thái đăng nhập sinh trắc học
enum BiometricLoginStatus {
  success,
  notAvailable,
  notEnabled,
  notEnrolled, // MỚI: Đã có phần cứng nhưng chưa cài đặt khuôn mặt/vân tay
  authFailed,
  noCredentials,
  loginApiFailed,
  unknownError,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();
  final GoogleAuthService _googleAuthService = getIt<GoogleAuthService>();
  final BiometricService _biometricService = getIt<BiometricService>();
  
  UserModel? _currentUser;
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
    try {
      final accessToken = await TokenHelper.getAccessToken();
      if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
        final decodedToken = JwtDecoder.decode(accessToken);
        _currentUser = _fromDecodedToken(decodedToken);
        await getProfile();
      }
    } catch (_) {
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, String?>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String? deviceToken;
    String? deviceType = "ANDROID";
    String? deviceName = "Unknown";

    try {
      deviceToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("FCM Token Error: $e");
    }

    try {
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
      }
    } catch (e) {
       debugPrint("Device Info Error: $e");
    }

    return {
      "deviceToken": deviceToken,
      "deviceType": deviceType,
      "deviceName": deviceName,
    };
  }

  Future<bool> login(String username, String password, BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final info = await _getDeviceInfo();
      final request = LoginRequest(
        username: username,
        password: password,
        deviceToken: info["deviceToken"],
        deviceType: info["deviceType"],
        deviceName: info["deviceName"],
      );

      final response = await _authService.login(request);
      if (response.success && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        await getProfile();
        if (context.mounted) context.read<NotificationProvider>().fetchNotifications();
        await TokenHelper.saveCredentials(username, password);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Server connection error.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleAuth = await _googleAuthService.signInWithGoogle();
      if (googleAuth == null || googleAuth.idToken == null) {
        _errorMessage = "Login was cancelled or could not connect to Google.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final info = await _getDeviceInfo();
      final response = await _authService.loginWithGoogle(
        idToken: googleAuth.idToken!,
        deviceToken: info["deviceToken"],
        deviceType: info["deviceType"],
        deviceName: info["deviceName"],
      );
      if (response.success && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        await getProfile();
        if (context.mounted) context.read<NotificationProvider>().fetchNotifications();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.message ?? "This Google account is not authorized or authentication error.";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error during Google login processing.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<BiometricLoginStatus> loginWithBiometric(BuildContext context, {String? customMessage}) async {
    try {
      // 1. Kiểm tra phần cứng có hỗ trợ không
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) return BiometricLoginStatus.notAvailable;

      // 2. Kiểm tra người dùng đã setup khuôn mặt/vân tay trong cài đặt máy chưa
      final isEnrolled = await _biometricService.isBiometricEnrolled();
      if (!isEnrolled) return BiometricLoginStatus.notEnrolled;

      // 3. Kiểm tra tính năng này đã được bật trong App chưa
      final isEnabled = await TokenHelper.isBiometricEnabled();
      if (!isEnabled) return BiometricLoginStatus.notEnabled;

      // 4. Thực hiện xác thực
      final authenticated = await _biometricService.authenticate(customMessage: customMessage);
      if (!authenticated) return BiometricLoginStatus.authFailed;

      final creds = await TokenHelper.getCredentials();
      final username = creds['username'];
      final password = creds['password'];

      if (username != null && password != null) {
        final success = await login(username, password, context);
        return success ? BiometricLoginStatus.success : BiometricLoginStatus.loginApiFailed;
      } else {
        final accessToken = await TokenHelper.getAccessToken();
        if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
          final decodedToken = JwtDecoder.decode(accessToken);
          _currentUser = _fromDecodedToken(decodedToken);
          await getProfile();
          if (context.mounted) context.read<NotificationProvider>().fetchNotifications();
          notifyListeners();
          return BiometricLoginStatus.success;
        }
        return BiometricLoginStatus.noCredentials;
      }
    } catch (e) {
      debugPrint("Biometric login error: $e");
      return BiometricLoginStatus.unknownError;
    }
  }

  Future<bool> canUseBiometric() async {
    return await _biometricService.isBiometricAvailable();
  }

  Future<void> toggleBiometric(bool enabled) async {
    await TokenHelper.setBiometricEnabled(enabled);
    if (!enabled) {
      await TokenHelper.clearBiometricConfig();
    }
    notifyListeners();
  }

  Future<bool> isBiometricEnabled() async {
    return await TokenHelper.isBiometricEnabled();
  }

  Future<bool> register(String? email, String? phone, String password, String confirmPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final request = RegisterRequest(accEmail: email, accPhone: phone, password: password, confirmPassword: confirmPassword);
      final response = await _authService.register(request);
      if (response.success) {
        _successMessage = response.message ?? 'Registration successful';
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Cannot connect to server.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    _setLoading(true);
    try {
      String? deviceToken = await FirebaseMessaging.instance.getToken();
      await _authService.logout(deviceToken: deviceToken ?? "");
    } catch (_) {} finally {
      _currentUser = null;
      await TokenHelper.clearTokens();
      await _googleAuthService.signOutGoogle();
      _setLoading(false);
      notifyListeners();
      if (context.mounted) context.go("/login");
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    try {
      final response = await _authService.forgotPassword(email);
      return response.success == true;
    } catch (_) { return false; } finally { _setLoading(false); }
  }

  Future<bool> confirmResetPassword({required String email, required String otp, required String newPassword}) async {
    _setLoading(true);
    try {
      final response = await _authService.resetPassword(email, otp, newPassword);
      return response.success == true;
    } catch (_) { return false; } finally { _setLoading(false); }
  }

  Future<void> getProfile() async {
    try {
      final response = await _authService.getProfile();
      if (response.success == true && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Get Profile Error: $e");
    }
  }

  Future<String?> updateAvatar(String filePath) async {
    _setLoading(true);
    try {
      final response = await _authService.updateAvatar(filePath);
      if (response.success == true && response.data != null) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(avatarUrl: response.data);
          notifyListeners();
        }
        return response.data;
      }
      return null;
    } catch (_) { return null; } finally { _setLoading(false); }
  }

  Future<bool> updateProfile(UpdateProfileRequest request) async {
    _setLoading(true);
    try {
      final response = await _authService.updateProfile(request);
      if (response.success == true && response.data != null) {
        _currentUser = UserModel.fromAuthResponse(response.data!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) { return false; } finally { _setLoading(false); }
  }

  Future<bool> sendEmergencyLockOTP(String identityCard) async {
    _setLoading(true);
    try {
      final response = await _authService.sendEmergencyLockOTP(identityCard);
      return response.success == true;
    } catch (_) { return false; } finally { _setLoading(false); }
  }

  Future<bool> verifyAndLockAccount(String otpCode) async {
    _setLoading(true);
    try {
      final response = await _authService.verifyAndLockAccount(otpCode);
      return response.success == true;
    } catch (_) { return false; } finally { _setLoading(false); }
  }

  String _extractErrorMessage(dynamic response) {
    if (response.message != null && response.message!.isNotEmpty) return response.message!;
    return 'An error occurred. Please try again.';
  }

  UserModel _fromDecodedToken(Map<String, dynamic> decodedToken) {
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
    return UserModel(
      userId: decodedToken['userId'],
      accEmail: sub.contains('@') ? sub : null,
      accPhone: !sub.contains('@') ? sub : null,
      roleCode: roleCode,
      permissions: permissions,
    );
  }
}
