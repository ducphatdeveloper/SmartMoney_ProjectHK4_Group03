import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  // Service gọi API
  final CategoryService _categoryService = CategoryService();

  // Dữ liệu gốc từ Server
  List<CategoryModel> _allCategories = [];

  // Trạng thái loading
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Trạng thái lỗi
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- GETTER CHO CÁC TAB (Đã lọc & Sắp xếp sẵn) ---

  // 1. Danh sách Vay/Nợ
  List<CategoryModel> get debtList {
    final rawList = _allCategories.where((c) => _isDebtCategory(c)).toList();
    return CategoryModel.sortCategories(rawList);
  }

  // 2. Danh sách Chi (Trừ Vay/Nợ)
  List<CategoryModel> get expenseList {
    final rawList = _allCategories.where((c) =>
    c.ctgType == false && !_isDebtCategory(c)
    ).toList();
    return CategoryModel.sortCategories(rawList);
  }

  // 3. Danh sách Thu (Trừ Vay/Nợ)
  List<CategoryModel> get incomeList {
    final rawList = _allCategories.where((c) =>
    c.ctgType == true && !_isDebtCategory(c)
    ).toList();
    return CategoryModel.sortCategories(rawList);
  }

  // --- HÀM GỌI API ---
  Future<void> fetchCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Báo UI hiện loading

    try {
      _allCategories = await _categoryService.getCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners(); // Báo UI cập nhật dữ liệu hoặc lỗi
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