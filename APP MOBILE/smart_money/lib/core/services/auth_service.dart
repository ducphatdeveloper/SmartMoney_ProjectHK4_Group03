import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

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

  /// Hàm helper để kiểm tra response và xử lý lỗi 401
  Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      // Token hết hạn hoặc không hợp lệ -> Xóa sạch token local
      await TokenHelper.clearTokens();
    }
  }

  // =============================================
  // LOGIN
  // =============================================
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
  Future<ApiResponse<dynamic>> register(RegisterRequest request) async {
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
  Future<void> logout({required String deviceToken}) async {
    try {
      final token = await TokenHelper.getAccessToken();
      await http.post(
        Uri.parse("${AppConstants.authLogout}?deviceToken=$deviceToken"),
        headers: {
          "Content-Type":  "application/json",
          "Authorization": "Bearer ${token ?? ''}",
        },
      );
    } catch (_) {
    } finally {
      await TokenHelper.clearTokens();
    }
  }

  // =============================================
  // PROFILE / AVATAR
  // =============================================

  Future<ApiResponse<AuthResponse>> getProfile() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.userProfile), headers: await _getHeaders());
      await _handleUnauthorized(response);
      return ApiResponse<AuthResponse>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), (data) => AuthResponse.fromJson(data));
    } catch (e) {
      return ApiResponse<AuthResponse>(success: false, message: "Lỗi lấy thông tin.");
    }
  }

  Future<ApiResponse<AuthResponse>> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await http.patch(Uri.parse(AppConstants.userProfile), headers: await _getHeaders(), body: jsonEncode(request.toJson()));
      await _handleUnauthorized(response);
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
      await _handleUnauthorized(response);
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
      await _handleUnauthorized(response);
      return ApiResponse<dynamic>.fromJson(jsonDecode(utf8.decode(response.bodyBytes)), null);
    } catch (e) {
      return ApiResponse<dynamic>(success: false, message: "Lỗi gửi mã OTP.");
    }
  }

  Future<ApiResponse<dynamic>> verifyAndLockAccount(String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConstants.userVerifyAndLock}?otpCode=$otpCode"),
        headers: await _getHeaders(),
      );
      await _handleUnauthorized(response);
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
