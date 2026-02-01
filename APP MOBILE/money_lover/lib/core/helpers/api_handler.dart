import 'dart:convert';
import 'package:http/http.dart' as http;

// Lớp helper trung tâm để xử lý logic gọi API và bắt lỗi.
class ApiHandler {
  // Hàm xử lý chung, bao bọc toàn bộ logic try-catch và kiểm tra status code.
  // - `request`: Hành động gọi API (ví dụ: http.get(...)).
  // - `onSuccess`: Hàm để biến đổi dữ liệu JSON thành đối tượng Dart.
  // - `activityName`: Tên của hành động để ghi log cho dễ hiểu.
  static Future<T> handleApiCall<T>({
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
        // Ném lỗi server để khối catch bên dưới xử lý.
        throw 'Lỗi Server: ${response.statusCode}';
      }
    } catch (e) {
      // Bất kỳ lỗi nào (kết nối, server, parse...) đều được xử lý tại đây.
      print("❌ Đã có lỗi xảy ra ($activityName): $e");
      // Ném ra một thông báo lỗi duy nhất, thân thiện cho UI hiển thị.
      throw 'Không thể hoàn thành "$activityName". Vui lòng thử lại.';
    }
  }
}
