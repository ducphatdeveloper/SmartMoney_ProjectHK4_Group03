import 'package:flutter/material.dart';
import '../models/saving_goal_response.dart';
import '../models/saving_goal_request.dart';
import '../services/saving_goal_service.dart';

class SavingGoalProvider extends ChangeNotifier {
  // =============================================
  // STATE
  // =============================================
  List<SavingGoalResponse> _goals = [];
  List<SavingGoalResponse> get goals => _goals;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Trạng thái tab hiện tại: false = Đang thực hiện, true = Hoàn thành
  bool _currentFilter = false;
  bool get currentFilter => _currentFilter;

  // Bộ nhớ đệm để chuyển tab mượt mà
  final Map<bool, List<SavingGoalResponse>> _cache = {};

  // =============================================
  // [1.1] LOAD GOALS - Cập nhật logic theo Tab
  // =============================================
  Future<void> loadGoals(bool isFinished, {bool forceRefresh = false, String? search}) async {
    _currentFilter = isFinished;

    // Dùng cache nếu không bắt buộc load mới và không có từ khóa tìm kiếm
    if (!forceRefresh && _cache.containsKey(isFinished) && (search == null || search.isEmpty)) {
      _goals = _cache[isFinished]!;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Gọi service getByStatus (hàm mới viết lại dựa trên EventService)
      final response = await SavingGoalService.getByStatus(
          isFinished: isFinished,
          search: search
      );

      if (response.success && response.data != null) {
        _goals = response.data!;
        // Lưu vào cache nếu không phải search
        if (search == null || search.isEmpty) {
          _cache[isFinished] = response.data!;
        }
      } else {
        _goals = [];
        _errorMessage = response.message;
      }
    } catch (e) {
      _goals = [];
      _errorMessage = "Lỗi kết nối máy chủ";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.2] CREATE - Giữ nguyên
  // =============================================
  Future<bool> createGoal(SavingGoalRequest request) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.create(request);
      if (response.success) {
        _cache.clear();
        await loadGoals(false, forceRefresh: true);
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi tạo mới";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.3] UPDATE - Giữ nguyên
  // =============================================
  Future<bool> updateGoal(int id, SavingGoalRequest request) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.update(id, request);
      if (response.success) {
        await loadGoals(_currentFilter, forceRefresh: true);
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi cập nhật";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.4] TOGGLE STATUS - Cập nhật logic chuyển Tab
  // =============================================
  Future<bool> toggleStatus(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.toggleStatus(id);
      if (response.success) {
        // Xóa item khỏi danh sách hiện tại ngay lập tức để thấy hiệu ứng chuyển tab
        _goals.removeWhere((g) => g.id == id);

        // Xóa cache vì dữ liệu giữa 2 tab đã thay đổi
        _cache.clear();

        notifyListeners();
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi khi thay đổi trạng thái";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.5] DELETE - Giữ nguyên
  // =============================================
  Future<bool> deleteGoal(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.delete(id);
      if (response.success) {
        _goals.removeWhere((g) => g.id == id);
        _cache[_currentFilter]?.removeWhere((g) => g.id == id);
        notifyListeners();
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi xóa";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.6] DEPOSIT - Giữ nguyên
  // =============================================
  Future<bool> depositMoney(int id, double amount) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.deposit(id, amount);
      if (response.success) {
        // Load lại tab hiện tại để cập nhật số dư/tiến độ
        await loadGoals(_currentFilter, forceRefresh: true);
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi nạp tiền";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCache() {
    _cache.clear();
    _goals = [];
    notifyListeners();
  }
}