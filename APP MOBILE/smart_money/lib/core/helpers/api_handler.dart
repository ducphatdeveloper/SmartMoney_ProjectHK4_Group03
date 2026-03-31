// core/helpers/api_handler.dart
// Trung tâm xử lý HTTP — tự gắn token, bắt lỗi 401/403/500
// Team chỉ cần gọi ApiHandler.get() ApiHandler.post() là xong
// KHÔNG cần tự viết header, tự lấy token mỗi file

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_helper.dart';
import '../models/api_response.dart';

class ApiHandler {

  // Tự động gắn Authorization header vào mọi request
  static Future<Map<String, String>> _buildHeaders() async {
    final token = await TokenHelper.getAccessToken();
    return {
      "Content-Type":  "application/json",
      "Authorization": "Bearer ${token ?? ''}",
    };
  }

  // =============================================
  // GET
  // =============================================
  static Future<ApiResponse<T>> get<T>(
      String url, {
        T Function(dynamic)? fromJson,
      }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _buildHeaders(),
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _networkError();
    }
  }

  // =============================================
  // POST
  // =============================================
  static Future<ApiResponse<T>> post<T>(
      String url, {
        Map<String, dynamic>? body,
        T Function(dynamic)? fromJson,
      }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _networkError();
    }
  }

  // =============================================
  // PUT
  // =============================================
  static Future<ApiResponse<T>> put<T>(
      String url, {
        Map<String, dynamic>? body,
        T Function(dynamic)? fromJson,
      }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: await _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _networkError();
    }
  }

  // =============================================
  // DELETE
  // =============================================
  static Future<ApiResponse<T>> delete<T>(
      String url, {
        T Function(dynamic)? fromJson,
      }) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: await _buildHeaders(),
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _networkError();
    }
  }

  // =============================================
  // PATCH — dùng cho toggle active/inactive
  // =============================================
  static Future<ApiResponse<T>> patch<T>(
      String url, {
        Map<String, dynamic>? body,
        T Function(dynamic)? fromJson,
      }) async {
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: await _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return _networkError();
    }
  }

  // =============================================
  // XỬ LÝ RESPONSE CHUNG
  // =============================================
  static ApiResponse<T> _handleResponse<T>(
      http.Response response,
      T Function(dynamic)? fromJson,
      ) {
    final json = jsonDecode(utf8.decode(response.bodyBytes));

    // 401 → Token hết hạn → cần refresh hoặc logout
    if (response.statusCode == 401) {
      return ApiResponse<T>(
        success: false,
        message: "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.",
      );
    }

    // 403 → Không có quyền
    if (response.statusCode == 403) {
      return ApiResponse<T>(
        success: false,
        message: "Bạn không có quyền thực hiện thao tác này.",
      );
    }

    return ApiResponse<T>.fromJson(json, fromJson);
  }

  static ApiResponse<T> _networkError<T>() {
    return ApiResponse<T>(
      success: false,
      message: "Không thể kết nối đến server. Kiểm tra lại mạng.",
    );
  }
}
