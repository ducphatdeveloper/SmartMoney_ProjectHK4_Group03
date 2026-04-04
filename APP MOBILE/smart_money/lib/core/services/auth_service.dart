import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '../../modules/auth/models/update_profile_request.dart';
import '../constants/app_constants.dart';
import '../helpers/token_helper.dart';
import '../models/api_response.dart';
import '../../modules/auth/models/login_request.dart';
import '../../modules/auth/models/register_request.dart';
import '../../modules/auth/models/auth_response.dart';

class AuthService {

  // Helper tạo Header chuẩn cho JWT
  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenHelper.getAccessToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }
  // =============================================
  // LOGIN
  // =============================================
  // Gọi POST /api/auth/login
  // Nhận LoginRequest → trả về ApiResponse<AuthResponse>
  Future<ApiResponse<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.authLogin),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final apiResponse = ApiResponse<AuthResponse>.fromJson(
        json,
            (data) => AuthResponse.fromJson(data),
      );

      // Đăng nhập thành công → tự lưu token vào flutter_secure_storage
      if (apiResponse.success && apiResponse.data != null) {
        await TokenHelper.saveTokens(
          apiResponse.data!.accessToken,
          apiResponse.data!.refreshToken,
        );
      }

      return apiResponse;

    } catch (e) {
      return ApiResponse<AuthResponse>(
        success: false,
        message: "Không thể kết nối đến server. Kiểm tra lại mạng.",
      );
    }
  }

  // =============================================
  // REGISTER
  // =============================================
  // Gọi POST /api/auth/register
  // Nhận RegisterRequest → trả về ApiResponse<dynamic>
  Future<ApiResponse<dynamic>> register(RegisterRequest request) async {
    // Validate phía client trước khi gọi API
    final error = request.validate();
    if (error != null) {
      return ApiResponse<dynamic>(success: false, message: error);
    }

    try {
      final response = await http.post(
        Uri.parse(AppConstants.authRegister),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return ApiResponse<dynamic>.fromJson(json, null);

    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: "Không thể kết nối đến server. Kiểm tra lại mạng.",
      );
    }
  }

  // =============================================
  // LOGOUT
  // =============================================
  // ⚠️ Spring Boot dùng @RequestParam
  // → Gọi POST /api/auth/logout?deviceToken=xxx
  Future<void> logout({required String deviceToken}) async {
    try {
      await http.post(
        Uri.parse("${AppConstants.authLogout}?deviceToken=$deviceToken"),
        headers: {
          "Content-Type":  "application/json",
          "Authorization": "Bearer ${await TokenHelper.getAccessToken() ?? ''}",
        },
      );
    } catch (_) {
      // Dù server lỗi vẫn xóa token local
    } finally {
      // Luôn xóa token dù server có lỗi hay không
      await TokenHelper.clearTokens();
    }
  }

  // =============================================
  // PROFILE / AVATAR
  // =============================================

  Future<ApiResponse<AuthResponse>> getProfile() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.userProfile), headers: await _getHeaders());
      return ApiResponse<AuthResponse>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), (data) => AuthResponse.fromJson(data));
    } catch (e) {
      return ApiResponse<AuthResponse>(success: false, message: "Lỗi lấy thông tin.");
    }
  }

  Future<ApiResponse<AuthResponse>> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await http.patch(Uri.parse(AppConstants.userProfile), headers: await _getHeaders(), body: jsonEncode(request.toJson()));
      return ApiResponse<AuthResponse>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), (data) => AuthResponse.fromJson(data));
    } catch (e) {
      return ApiResponse<AuthResponse>(success: false, message: "Lỗi cập nhật.");
    }
  }

  Future<ApiResponse<String>> updateAvatar(String filePath) async {
    try {
      final uri = Uri.parse(AppConstants.userAvatar);
      final request = http.MultipartRequest('POST', uri);
      final token = await TokenHelper.getAccessToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath, contentType: MediaType('image', 'jpeg')));
      final response = await http.Response.fromStream(await request.send());
      return ApiResponse<String>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), (data) => data.toString());
    } catch (e) {
      return ApiResponse<String>(success: false, message: "Lỗi avatar.");
    }
  }

  // =============================================
  // EMERGENCY LOCK
  // =============================================

  Future<ApiResponse<dynamic>> sendEmergencyLockOTP(String identityCard) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConstants.userSendLockOtp}?identityCard=$identityCard"),
        headers: await _getHeaders(),
      );
      return ApiResponse<dynamic>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), null);
    } catch (e) {
      return ApiResponse<dynamic>(success: false, message: "Lỗi gửi mã OTP.");
    }
  }

  Future<ApiResponse<dynamic>> verifyAndLockAccount(String otpCode) async {
    try {
      // Gửi OTP qua @RequestParam như thiết kế của bạn
      final response = await http.post(
        Uri.parse("${AppConstants.userVerifyAndLock}?otpCode=$otpCode"),
        headers: await _getHeaders(),
      );
      return ApiResponse<dynamic>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), null);
    } catch (e) {
      return ApiResponse<dynamic>(success: false, message: "Lỗi xác nhận.");
    }
  }
  // =============================================
  // FORGOT / RESET PASSWORD
  // =============================================
  Future<ApiResponse<dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(Uri.parse(AppConstants.authForgotPassword), headers: {"Content-Type": "application/json"}, body: jsonEncode({"email": email}));
      return ApiResponse<dynamic>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), null);
    } catch (e) { return ApiResponse<dynamic>(success: false, message: "Lỗi server."); }
  }

  Future<ApiResponse<dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(Uri.parse(AppConstants.authResetPassword), headers: {"Content-Type": "application/json"}, body: jsonEncode({"email": email, "otp": otp, "newPassword": newPassword}));
      return ApiResponse<dynamic>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), null);
    } catch (e) { return ApiResponse<dynamic>(success: false, message: "Lỗi server."); }
  }
}
