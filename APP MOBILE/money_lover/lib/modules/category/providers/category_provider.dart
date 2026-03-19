import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart'; // Import get_it
import '../models/category_model.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  // Lấy CategoryService thông qua GetIt
  final CategoryService _categoryService = GetIt.I<CategoryService>();

  List<CategoryModel> _allCategories = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- GETTER CHO CÁC TAB (Đã lọc & Sắp xếp sẵn) ---
  List<CategoryModel> get debtList => CategoryModel.sortCategories(_allCategories.where((c) => _isDebtCategory(c)).toList());
  List<CategoryModel> get expenseList => CategoryModel.sortCategories(_allCategories.where((c) => c.ctgType == false && !_isDebtCategory(c)).toList());
  List<CategoryModel> get incomeList => CategoryModel.sortCategories(_allCategories.where((c) => c.ctgType == true && !_isDebtCategory(c)).toList());

  // --- HÀM GỌI API ---

  // Lấy tất cả danh mục (có thể lọc theo group)
  Future<void> fetchCategories({String? group}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allCategories = await _categoryService.getCategories(group: group);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Thêm danh mục mới
  Future<void> addCategory(CategoryModel newCategory) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final addedCategory = await _categoryService.createCategory(newCategory);
      _allCategories.add(addedCategory); // Cập nhật danh sách trong bộ nhớ
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật danh mục
  Future<void> updateCategory(CategoryModel updatedCategory) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resultCategory = await _categoryService.updateCategory(updatedCategory);
      final index = _allCategories.indexWhere((c) => c.id == resultCategory.id);
      if (index != -1) {
        _allCategories[index] = resultCategory; // Cập nhật danh sách trong bộ nhớ
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Xóa danh mục
  Future<void> deleteCategory(int categoryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _categoryService.deleteCategory(categoryId);
      _allCategories.removeWhere((c) => c.id == categoryId); // Xóa khỏi danh sách trong bộ nhớ
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HÀM HELPER (Logic lọc Vay/Nợ) ---
  bool _isDebtCategory(CategoryModel c) {
    final name = c.ctgName.toLowerCase();
    return name.contains("vay") ||
        name.contains("nợ") ||
        name.contains("thu nợ") ||
        name.contains("trả nợ");
  }
}
