// ===========================================================
// [2] CategoryProvider — Quản lý state module Danh mục
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ danh sách danh mục theo 3 tab (expense, income, debt)
//   • Gọi CategoryService để CRUD
//   • Thông báo UI khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong UI:
//   final provider = Provider.of<CategoryProvider>(context);
//   provider.loadByGroup("expense");
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/models/category_request.dart';
import 'package:smart_money/modules/category/services/category_service.dart';

class CategoryProvider extends ChangeNotifier {

  // =============================================
  // [2.1] STATE — Danh sách danh mục theo từng tab
  // =============================================

  // Danh sách danh mục cho tab hiện tại
  List<CategoryResponse> _categories = [];
  List<CategoryResponse> get categories => _categories;

  // Danh sách danh mục cha — dùng khi tạo/sửa danh mục con
  List<CategoryResponse> _parentCategories = [];
  List<CategoryResponse> get parentCategories => _parentCategories;

  // Kết quả tìm kiếm — hiện khi user gõ thanh search
  List<CategoryResponse> _searchResults = [];
  List<CategoryResponse> get searchResults => _searchResults;

  // Tab đang chọn: "expense" | "income" | "debt"
  String _currentGroup = 'expense';
  String get currentGroup => _currentGroup;

  // Trạng thái loading — hiện vòng xoay khi đang gọi API (cho category list)
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Trạng thái loading riêng cho loadParents / loadMergeTargets
  // → Tránh làm trigger rebuild toàn bộ CategoryTabContent khi mở bottom sheet
  bool _isLoadingSheet = false;
  bool get isLoadingSheet => _isLoadingSheet;

  // Thông báo lỗi — hiện SnackBar khi API lỗi
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Thông báo thành công — hiện SnackBar khi tạo/sửa/xóa OK
  String? _successMessage;
  String? get successMessage => _successMessage;

  // =============================================
  // [2.1b] CACHE — Lưu danh mục của mỗi group
  // =============================================
  // Dùng để tránh gọi API mỗi khi chuyển tab
  // Key: "expense" | "income" | "debt"
  // Value: Danh sách CategoryResponse đã load
  final Map<String, List<CategoryResponse>> _cachedByGroup = {};

  // =============================================
  // [2.2] LOAD — Lấy danh sách theo nhóm (3 tab)
  // =============================================
  // Logic:
  //   1. Nếu đã cache → hiện cache luôn (mượt, không lag)
  //   2. Sau đó background load từ API (optional refresh)
  //   3. Nếu chưa cache → load từ API (lần đầu mở tab)
  //
  // Gọi khi: Mở màn hình, chuyển tab lần đầu, sau khi tạo/sửa/xóa
  // API: GET /api/categories?group=expense
  Future<void> loadByGroup(String group, {bool forceRefresh = false}) async {
    // Bước 0: Nếu đã cache và không force refresh → dùng cache
    if (!forceRefresh && _cachedByGroup.containsKey(group)) {
      _categories = _cachedByGroup[group]!;
      _currentGroup = group;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // Bước 1: Bật loading, xóa lỗi cũ (chỉ lần đầu không có cache)
    if (!_cachedByGroup.containsKey(group)) {
      _isLoading = true;
    }
    _errorMessage = null;
    _currentGroup = group; // lưu tab đang chọn
    notifyListeners();

    // Bước 2: Gọi API qua CategoryService
    final response = await CategoryService.getByGroup(group);

    // Bước 3: Xử lý kết quả + cache
    if (response.success && response.data != null) {
      _categories = response.data!;
      _cachedByGroup[group] = response.data!; // lưu cache
    } else {
      _categories = [];
      _errorMessage = response.message; // lỗi từ server (tiếng Việt)
    }

    // Bước 4: Tắt loading, thông báo UI cập nhật
    _isLoading = false;
    notifyListeners();
  }

  // =============================================
  // [2.2b] CLEAR CACHE — Xóa cache khi quay lại screen
  // =============================================
  // Logic:
  //   • Dùng khi user quay lại từ create/edit/delete hoặc screen khác
  //   • Xóa toàn bộ cache → lần load tiếp theo sẽ gọi API (fresh data)
  //   • Tránh dính cache stale khi dữ liệu thay đổi từ nơi khác
  void clearCache() {
    _cachedByGroup.clear();
    _categories = [];
    _currentGroup = 'expense';
    _isLoading = false;
    _isLoadingSheet = false;
    _errorMessage = null;
  }

  // =============================================
  // [2.3] SEARCH — Tìm kiếm danh mục
  // =============================================
  // Gọi khi: User gõ vào thanh search
  // API: GET /api/categories/search?name=Ăn
  Future<void> searchCategories(String? keyword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await CategoryService.search(keyword);

    if (response.success && response.data != null) {
      _searchResults = response.data!;
    } else {
      _searchResults = [];
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  // =============================================
  // [2.4] LOAD PARENTS — Lấy danh mục cha
  // =============================================
  // Gọi khi: Mở bottom sheet chọn nhóm cha (tạo/sửa danh mục con)
  // API: GET /api/categories/parents?type=false
  // ctgType: true = Thu nhập, false = Chi tiêu
  // Dùng _isLoadingSheet thay vì _isLoading để tránh trigger rebuild CategoryTabContent
  Future<void> loadParents(bool ctgType) async {
    _isLoadingSheet = true;
    _errorMessage = null;
    notifyListeners();

    final response = await CategoryService.getParents(ctgType);

    if (response.success && response.data != null) {
      _parentCategories = response.data!;
    } else {
      _parentCategories = [];
      _errorMessage = response.message;
    }

    _isLoadingSheet = false;
    notifyListeners();
  }

  // =============================================
  // [2.5] CREATE — Tạo danh mục mới
  // =============================================
  // API: POST /api/categories
  // [FIX-3] Dùng _extractErrorMessage để xử lý cả 2 dạng lỗi từ server
  Future<bool> createCategory(CategoryRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final response = await CategoryService.create(request);

    if (response.success) {
      _successMessage = response.message; // "Tạo danh mục thành công"
      await loadByGroup(_currentGroup); // reload danh sách
      return true;
    } else {
      // [FIX-3] Gom lỗi field-level validation thành string đọc được
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.6] UPDATE — Cập nhật danh mục
  // =============================================
  // API: PUT /api/categories/{id}
  Future<bool> updateCategory(int id, CategoryRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final response = await CategoryService.update(id, request);

    if (response.success) {
      _successMessage = response.message; // "Cập nhật danh mục thành công"
      await loadByGroup(_currentGroup);
      return true;
    } else {
      _errorMessage = _extractErrorMessage(response); // [FIX-3]
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.7] DELETE — Xóa danh mục (không truyền actionType)
  // =============================================
  // API: DELETE /api/categories/{id}
  // ⚠️ Khi actionType = null → Backend mặc định DELETE_ALL
  //    → Xóa sạch giao dịch (con + cha) + xóa danh mục (con + cha) → luôn thành công
  // ⚠️ Hiện tại không dùng — UI gọi deleteCategoryWithOptions() thay thế
  //    để truyền actionType rõ ràng (DELETE_ALL hoặc MERGE)
  Future<bool> deleteCategory(int id) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final response = await CategoryService.delete(id);

    if (response.success) {
      _successMessage = response.message; // "Xóa danh mục thành công" (cả cha + con)
      await loadByGroup(_currentGroup);
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.8] LOAD MERGE TARGETS — Lấy danh mục nhận gộp
  // =============================================
  // Gọi khi: User chọn MERGE → cần hiện danh sách danh mục cùng loại
  // API: GET /api/categories/merge-targets?type=true|false
  // excludeId: loại bỏ danh mục đang xóa ra khỏi danh sách
  // Dùng _isLoadingSheet để tránh trigger reload CategoryTabContent
  List<CategoryResponse> _mergeTargets = [];
  List<CategoryResponse> get mergeTargets => _mergeTargets;

  Future<void> loadMergeTargets(bool ctgType, {int? excludeId}) async {
    _isLoadingSheet = true;
    _errorMessage = null;
    notifyListeners();

    final response = await CategoryService.getMergeTargets(ctgType);

    if (response.success && response.data != null) {
      // Loại bỏ danh mục đang xóa ra khỏi danh sách chọn
      _mergeTargets = response.data!
          .where((c) => c.id != excludeId)
          .toList();
    } else {
      _mergeTargets = [];
      _errorMessage = response.message;
    }

    _isLoadingSheet = false;
    notifyListeners();
  }

  // =============================================
  // [2.9] DELETE WITH OPTIONS — Xóa + MERGE hoặc DELETE_ALL
  // =============================================
  // API: DELETE /api/categories/{id}?actionType=MERGE&newCategoryId=5
  //   hoặc: DELETE /api/categories/{id}?actionType=DELETE_ALL
  // Gọi khi: Danh mục có giao dịch → user đã chọn hành động
  Future<bool> deleteCategoryWithOptions({
    required int id,
    required String actionType,
    int? newCategoryId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    final response = await CategoryService.deleteWithOptions(
      id: id,
      actionType: actionType,
      newCategoryId: newCategoryId,
    );

    if (response.success) {
      _successMessage = response.message; // "Xóa danh mục thành công"
      await loadByGroup(_currentGroup); // reload danh sách
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.10] CLEAR — Xóa thông báo lỗi/thành công
  // =============================================
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // =============================================
  // [2.11] HELPER — Trích xuất message lỗi từ response
  // =============================================
  // [FIX-3] Backend trả 2 dạng lỗi:
  //   Dạng 1 — IllegalArgumentException (400):
  //     { "success": false, "message": "Danh mục 'X' đã tồn tại.", "data": null }
  //     → Dùng response.message trực tiếp
  //
  //   Dạng 2 — @Valid validation fail (400):
  //     { "success": false, "message": "Dữ liệu không hợp lệ",
  //       "data": { "ctgName": "Tên không được trống", "ctgType": "..." } }
  //     → data là Map<String, String> chứa field errors
  //     → Gom thành 1 string hiển thị
  String _extractErrorMessage(dynamic response) {
    // Thử đọc data — nếu là Map thì là lỗi validation theo field
    try {
      final raw = response.data;
      if (raw is Map && raw.isNotEmpty) {
        // Gom lỗi từng field: "Tên không được trống\nLoại không được trống"
        return raw.values.join('\n');
      }
    } catch (_) {
      // data null hoặc không phải Map → bỏ qua
    }

    // Fallback: message chính từ server (IllegalArgumentException, RuntimeException)
    return response.message ?? "Có lỗi xảy ra";
  }
}

