import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../helpers/token_helper.dart';
import '../models/api_response.dart';
import '../../modules/auth/models/login_request.dart';
import '../../modules/auth/models/register_request.dart';
import '../../modules/auth/models/auth_response.dart';

class AuthService {

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
}
