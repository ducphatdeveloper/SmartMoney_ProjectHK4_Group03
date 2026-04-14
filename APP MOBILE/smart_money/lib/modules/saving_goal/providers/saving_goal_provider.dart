import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/wallet/providers/wallet_provider.dart';
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

  bool _currentFilter = false;
  bool get currentFilter => _currentFilter;

  final Map<bool, List<SavingGoalResponse>> _cache = {};

  // =============================================
  // [1.1] LOAD GOALS
  // =============================================
  Future<void> loadGoals(bool isFinished, {bool forceRefresh = false, String? search}) async {
    _currentFilter = isFinished;

    if (!forceRefresh && _cache.containsKey(isFinished) && (search == null || search.isEmpty)) {
      _goals = _cache[isFinished]!;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SavingGoalService.getByStatus(isFinished: isFinished, search: search);
      if (response.success && response.data != null) {
        // Backend da loc theo isFinished server-side — khong can loc client-side nua
        
        _goals = response.data!;
        if (search == null || search.isEmpty) {
          _cache[isFinished] = _goals;
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
  // [1.2] CREATE
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
  // [1.3] UPDATE
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
  // [1.4] DELETE
  // =============================================
  Future<bool> deleteGoal(BuildContext context, int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.delete(id);
      if (response.success) {
        _handleStateChange(context, id);
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
  // [1.5] DEPOSIT
  // =============================================
  Future<bool> depositMoney(int id, double amount) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.deposit(id, amount);
      if (response.success) {
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

  // =============================================
  // [1.6] COMPLETE GOAL
  // =============================================
  Future<bool> completeGoal(BuildContext context, int id, {int? walletId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.completeSavingGoal(id, walletId: walletId);
      if (response.success) {
        _handleStateChange(context, id);
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi chốt sổ";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.7] CANCEL GOAL
  // =============================================
  Future<bool> cancelGoal(BuildContext context, int id, {int? walletId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SavingGoalService.cancelSavingGoal(id, walletId: walletId);
      if (response.success) {
        _handleStateChange(context, id);
        return true;
      }
      _errorMessage = response.message;
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi hủy mục tiêu";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [1.8] PRIVATE HELPER: Xử lý đồng bộ state
  // =============================================
  void _handleStateChange(BuildContext context, int id) {
    // 1. Xóa mục tiêu khỏi danh sách hiện tại (của tab Active)
    _goals.removeWhere((g) => g.id == id);
    
    // 2. Thông báo ngay cho UI của tab Active cập nhật (mục tiêu biến mất)
    notifyListeners();
    
    // 3. Xóa cache để lần sau chuyển tab sẽ tải lại dữ liệu mới
    _cache.clear();
    
    // 4. "Thông báo" cho các provider khác để chúng tự làm mới
    // Sử dụng try-catch để tránh lỗi nếu provider không được tìm thấy
    try {
      Provider.of<TransactionProvider>(context, listen: false).refreshSourceItems();
      Provider.of<WalletProvider>(context, listen: false).loadAll();
    } catch (e) {
      debugPrint("Could not find a provider to notify: $e");
    }
  }

  // =============================================
  // [1.9] CLEAR CACHE
  // =============================================
  void clearCache() {
    _cache.clear();
    _goals = [];
    notifyListeners();
  }
}
