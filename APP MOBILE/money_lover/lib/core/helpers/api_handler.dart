import 'dart:convert';
import 'package:http/http.dart' as http;

// Lớp helper trung tâm để xử lý logic gọi API và bắt lỗi.
class ApiHandler {
  // Hàm private xử lý logic chung, chỉ dùng nội bộ trong class này.
  static Future<T> _handleApiCall<T>({
    required Future<http.Response> request,
    required T Function(dynamic jsonData) onSuccess,
    required String activityName,
  }) async {
    try {
      print("🚀 Bắt đầu: $activityName");
      final response = await request;

      if (response.statusCode == 200) {
        print("✅ Thành công: $activityName");
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        return onSuccess(jsonData);
      } else {
        throw 'Lỗi Server: ${response.statusCode}';
      }
    } catch (e) {
      print("❌ Đã có lỗi xảy ra ($activityName): $e");
      throw 'Không thể hoàn thành "$activityName". Vui lòng thử lại.';
    }
  }

  // ======================== PHIÊN BẢN NÂNG CẤP ========================
  // Hàm mới, chuyên để fetch một danh sách.
  // Nó sẽ tự động parse JSON thành List và map qua từng phần tử.
  static Future<List<T>> fetchList<T>({
    required Future<http.Response> request,
    required T Function(Map<String, dynamic> itemJson) fromJson, // Chỉ cần truyền hàm fromJson
    required String activityName,
  }) {
    return _handleApiCall<List<T>>(
      request: request,
      activityName: activityName,
      onSuccess: (jsonData) {
        final List<dynamic> list = jsonData;
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      },
    );
  }
}
