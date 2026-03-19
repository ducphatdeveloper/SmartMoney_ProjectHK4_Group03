import 'dart:convert';
import 'package:http/http.dart' as http;

// Lớp helper trung tâm để xử lý logic gọi API và bắt lỗi.
class ApiHandler {
  // Hàm private xử lý logic chung, chỉ dùng nội bộ trong class này.
  static Future<T> _handleApiCall<T>({
    required Future<http.Response> Function(Map<String, String> headers) createRequest,
    required T Function(dynamic data) onSuccess, // Changed jsonData to data to reflect passing 'data' field
    required String activityName,
    String? token,
  }) async {
    try {
      print("🚀 Bắt đầu: $activityName");

      // Chuẩn bị headers
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };

      // Nếu có token, gắn vào header Authorization
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Tạo và gửi request với headers đã được chuẩn bị
      final response = await createRequest(headers);

      // Parse response body with every status code
      dynamic decodedBody;
      if (response.bodyBytes.isNotEmpty) {
        decodedBody = json.decode(utf8.decode(response.bodyBytes));
      } else {
        // Handle empty body, e.g., 204 No Content. Assume success if no body.
        decodedBody = {'success': true, 'message': 'No content', 'data': null};
      }

      // Check for success status codes (2xx range)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ Thành công: $activityName");
        // Backend might return 2xx but with success: false for business logic errors
        if (decodedBody is Map && decodedBody.containsKey('success') && decodedBody['success'] == false) {
          String errorMessage = decodedBody['message'] ?? 'Đã xảy ra lỗi.';
          if (decodedBody['data'] is Map && (decodedBody['data'] as Map).isNotEmpty) {
            errorMessage = (decodedBody['data'] as Map).values.first.toString();
          }
          throw errorMessage;
        }
        // If success: true or no 'success' field, pass the 'data' field or the whole body
        return onSuccess(decodedBody is Map && decodedBody.containsKey('data') ? decodedBody['data'] : decodedBody);
      } else {
        // Error from backend (non-2xx status code)
        final errorBody = decodedBody; // Use decodedBody as errorBody
        if (errorBody is Map && errorBody.containsKey('success') && errorBody['success'] == false) {
          String errorMessage = errorBody['message'] ?? 'Lỗi không xác định từ server';
          if (errorBody['data'] is Map && (errorBody['data'] as Map).isNotEmpty) {
            errorMessage = (errorBody['data'] as Map).values.first.toString();
          }
          throw errorMessage;
        }
        // Fallback for other error structures or if 'success' field is missing
        throw errorBody['message'] ?? 'Lỗi Server: ${response.statusCode}';
      }
    } catch (e) {
      print("❌ Đã có lỗi xảy ra ($activityName): $e");
      rethrow; // rethrow to propagate the correct message to the UI
    }
  }

  // Hàm GET một danh sách
  static Future<List<T>> getList<T>({
    required String url,
    required T Function(Map<String, dynamic> itemJson) fromJson,
    required String activityName,
    String? token,
  }) {
    return _handleApiCall<List<T>>(
      createRequest: (headers) => http.get(Uri.parse(url), headers: headers),
      activityName: activityName,
      token: token,
      onSuccess: (data) { // Changed jsonData to data here
        final List<dynamic> list = data; // data should be the list itself
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      },
    );
  }

  // Hàm POST để tạo mới dữ liệu
  static Future<T> post<T>({
    required String url,
    required Map<String, dynamic> body,
    required T Function(dynamic data) fromJson, // Changed jsonData to data
    required String activityName,
    String? token,
  }) {
    return _handleApiCall<T>(
      createRequest: (headers) => http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ),
      activityName: activityName,
      token: token,
      onSuccess: fromJson, // fromJson should expect the 'data' field
    );
  }

  // Hàm PUT để cập nhật dữ liệu
  static Future<T> put<T>({
    required String url,
    required Map<String, dynamic> body,
    required T Function(dynamic data) fromJson,
    required String activityName,
    String? token,
  }) {
    return _handleApiCall<T>(
      createRequest: (headers) => http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ),
      activityName: activityName,
      token: token,
      onSuccess: fromJson,
    );
  }

  // Hàm DELETE để xóa dữ liệu
  static Future<void> delete({ // Delete usually doesn't return data, so T is void
    required String url,
    required String activityName,
    String? token,
  }) {
    return _handleApiCall<void>(
      createRequest: (headers) => http.delete(Uri.parse(url), headers: headers),
      activityName: activityName,
      token: token,
      onSuccess: (data) => null, // For delete, no data is expected, so return null
    );
  }
}
