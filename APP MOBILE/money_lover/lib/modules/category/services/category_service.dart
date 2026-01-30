import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../models/category_model.dart';

class CategoryService {

  // Hàm gọi API lấy danh sách danh mục
  Future<List<CategoryModel>> getCategories() async {
    try {
      print("🚀 Đang gọi API: ${ApiConstants.categories}");

      final response = await http.get(Uri.parse(ApiConstants.categories));

      if (response.statusCode == 200) {
        print("✅ Kết nối thành công!");

        // 1. Giải mã UTF-8 để hiển thị tiếng Việt
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));

        // 2. Map từng phần tử JSON sang CategoryModel
        return jsonData.map((item) => CategoryModel.fromJson(item)).toList();
      } else {
        print("❌ Lỗi Server: ${response.statusCode}");
        throw Exception('Không thể tải danh mục: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Lỗi kết nối: $e");
      throw Exception('Lỗi kết nối đến server: $e');
    }
  }
}