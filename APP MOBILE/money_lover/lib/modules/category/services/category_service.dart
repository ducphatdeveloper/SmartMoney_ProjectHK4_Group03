import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart'; // Đã đổi tên từ api_constants.dart
import '../../../core/helpers/api_handler.dart';
import '../models/category_model.dart';

class CategoryService {
  final _storage = const FlutterSecureStorage();

  // Lấy danh sách danh mục
  Future<List<CategoryModel>> getCategories({String? group}) async {
    final token = await _storage.read(key: 'jwt_token');
    String url = "${AppConstants.baseUrl}/categories";
    if (group != null && group.isNotEmpty) {
      url += "?group=$group"; // Thêm filter group nếu có
    }

    return ApiHandler.getList<CategoryModel>( 
      url: url,
      fromJson: CategoryModel.fromJson,
      activityName: "Tải danh sách danh mục",
      token: token,
    );
  }

  // Tạo danh mục mới
  Future<CategoryModel> createCategory(CategoryModel newCategory) async {
    final token = await _storage.read(key: 'jwt_token');
    return ApiHandler.post<CategoryModel>(
      url: "${AppConstants.baseUrl}/categories",
      body: newCategory.toJson(), // Chuyển đổi model thành JSON để gửi đi
      fromJson: (json) => CategoryModel.fromJson(json as Map<String, dynamic>),
      activityName: "Tạo danh mục mới",
      token: token,
    );
  }

  // Cập nhật danh mục
  Future<CategoryModel> updateCategory(CategoryModel updatedCategory) async {
    final token = await _storage.read(key: 'jwt_token');
    return ApiHandler.put<CategoryModel>(
      url: "${AppConstants.baseUrl}/categories/${updatedCategory.id}", // URL có ID
      body: updatedCategory.toJson(),
      fromJson: (json) => CategoryModel.fromJson(json as Map<String, dynamic>),
      activityName: "Cập nhật danh mục",
      token: token,
    );
  }

  // Xóa danh mục
  Future<void> deleteCategory(int categoryId) async {
    final token = await _storage.read(key: 'jwt_token');
    return ApiHandler.delete(
      url: "${AppConstants.baseUrl}/categories/$categoryId", // URL có ID
      activityName: "Xóa danh mục",
      token: token,
    );
  }
}
