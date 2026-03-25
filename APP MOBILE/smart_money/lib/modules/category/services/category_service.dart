// ===========================================================
// [1] CategoryService — Gọi API danh mục từ Spring Boot
// ===========================================================
// Tương ứng: CategoryController.java (backend)
// Endpoints:
//   • GET  /api/categories?group=expense|income|debt
//   • GET  /api/categories/search?name=...
//   • GET  /api/categories/parents?type=true|false
//   • POST /api/categories
//   • PUT  /api/categories/{id}
//   • DELETE /api/categories/{id}
// ===========================================================

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/models/category_request.dart';

class CategoryService {

  // URL gốc: /api/categories (lấy từ AppConstants)
  static String get _base => AppConstants.categoriesBase;

  // -----------------------------------------------------------
  // [1.1] Lấy danh mục theo nhóm — cho 3 tab UI
  // -----------------------------------------------------------
  // group = "expense" | "income" | "debt"
  // Backend: CategoryController.getCategoriesByGroup()
  // Response: ApiResponse<List<CategoryResponse>>
  static Future<ApiResponse<List<CategoryResponse>>> getByGroup(String group) async {
    final url = '$_base?group=$group'; // VD: /api/categories?group=expense

    return ApiHandler.get<List<CategoryResponse>>(
      url,
      fromJson: (json) => _parseList(json), // parse danh sách từ json
    );
  }

  // -----------------------------------------------------------
  // [1.2] Tìm kiếm danh mục — toàn bộ (hệ thống + user)
  // -----------------------------------------------------------
  // name = từ khóa tìm kiếm (rỗng = lấy tất cả)
  // Backend: CategoryController.searchAllCategories()
  static Future<ApiResponse<List<CategoryResponse>>> search(String? name) async {
    // Nếu có từ khóa thì gắn query param, không thì bỏ qua
    final query = (name != null && name.trim().isNotEmpty)
        ? '?name=${Uri.encodeComponent(name.trim())}'
        : '';
    final url = '$_base/search$query'; // VD: /api/categories/search?name=Ăn

    return ApiHandler.get<List<CategoryResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.3] Lấy danh mục cha — dùng khi tạo danh mục con
  // -----------------------------------------------------------
  // ctgType: true = Thu nhập, false = Chi tiêu
  // Backend: CategoryController.getParentCategories()
  static Future<ApiResponse<List<CategoryResponse>>> getParents(bool ctgType) async {
    final url = '$_base/parents?type=$ctgType'; // VD: /api/categories/parents?type=false

    return ApiHandler.get<List<CategoryResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.4] Tạo danh mục mới
  // -----------------------------------------------------------
  // Backend: CategoryController.createCategory()
  // Lỗi có thể ném từ backend:
  //   • "Danh mục 'X' đã tồn tại trong mục 'Y'" (trùng tên con)
  //   • "Danh mục gốc 'X' đã tồn tại." (trùng tên gốc)
  //   • "Không thể tạo danh mục gốc trùng tên với danh mục của hệ thống."
  static Future<ApiResponse<CategoryResponse>> create(CategoryRequest request) async {
    return ApiHandler.post<CategoryResponse>(
      _base,                        // POST /api/categories
      body: request.toJson(),       // gửi body JSON
      fromJson: (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.5] Cập nhật danh mục
  // -----------------------------------------------------------
  // Backend: CategoryController.updateCategory()
  // Lỗi:
  //   • "Bạn không có quyền sửa danh mục này." (403)
  //   • "Tên danh mục 'X' đã được sử dụng." (400)
  static Future<ApiResponse<CategoryResponse>> update(int id, CategoryRequest request) async {
    final url = '$_base/$id'; // VD: /api/categories/25

    return ApiHandler.put<CategoryResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // -----------------------------------------------------------
  // [1.6] Xóa danh mục (không truyền actionType)
  // -----------------------------------------------------------
  // Backend: DELETE /api/categories/{id}
  // ⚠️ Khi actionType = null → Backend mặc định DELETE_ALL
  //    → Xóa sạch giao dịch (con + cha) + xóa danh mục (con + cha)
  //    → Luôn thành công (nếu danh mục hợp lệ + không phải hệ thống)
  // ⚠️ Hiện tại không dùng trực tiếp — dùng deleteWithOptions() thay thế
  //    để truyền actionType rõ ràng (DELETE_ALL hoặc MERGE)
  static Future<ApiResponse<void>> delete(int id) async {
    final url = '$_base/$id'; // VD: /api/categories/25

    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.7] Xóa danh mục với tùy chọn (MERGE hoặc DELETE_ALL)
  // -----------------------------------------------------------
  // Backend: DELETE /api/categories/{id}?actionType=MERGE&newCategoryId=5
  // actionType: "MERGE" (gộp giao dịch) hoặc "DELETE_ALL" (xóa giao dịch + hoàn tiền)
  // newCategoryId: ID danh mục nhận giao dịch (chỉ dùng khi MERGE)
  static Future<ApiResponse<void>> deleteWithOptions({
    required int id,
    required String actionType,
    int? newCategoryId,
  }) async {
    // Build URL với query params
    String url = '$_base/$id?actionType=$actionType';
    if (newCategoryId != null) {
      url += '&newCategoryId=$newCategoryId';
    }

    return ApiHandler.delete<void>(url);
  }

  // -----------------------------------------------------------
  // [1.8] Lấy danh sách danh mục nhận gộp (merge targets)
  // -----------------------------------------------------------
  // Backend: GET /api/categories/merge-targets?type=true|false
  // Dùng khi: User chọn MERGE → cần chọn danh mục nhận giao dịch
  // ctgType: true = Thu nhập, false = Chi tiêu (phải cùng loại)
  static Future<ApiResponse<List<CategoryResponse>>> getMergeTargets(bool ctgType) async {
    final url = '$_base/merge-targets?type=$ctgType';

    return ApiHandler.get<List<CategoryResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // -----------------------------------------------------------
  // [1.9] Helper nội bộ — Parse List<CategoryResponse> từ JSON
  // -----------------------------------------------------------
  static List<CategoryResponse> _parseList(dynamic json) {
    if (json is List) {
      return json
          .map((item) => CategoryResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return []; // trả rỗng nếu json không phải List
  }
}

