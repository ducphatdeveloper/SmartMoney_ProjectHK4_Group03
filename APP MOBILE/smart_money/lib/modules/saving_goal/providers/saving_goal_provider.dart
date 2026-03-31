import 'package:flutter/material.dart';
import '../models/saving_goal_response.dart';
import '../models/saving_goal_request.dart';
import '../services/saving_goal_service.dart';

class SavingGoalProvider extends ChangeNotifier {
  List<SavingGoalResponse> _goals = [];
  List<SavingGoalResponse> get goals => _goals;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadGoals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await SavingGoalService.getAll();
      if (response.success && response.data != null) {
        _goals = response.data!;
      } else {
        _errorMessage = response.message; // Lấy lỗi từ server nếu có
      }
    } catch (e) {
      _errorMessage = "Lỗi kết nối máy chủ";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGoal(SavingGoalRequest request) async {
    _isLoading = true;
    _errorMessage = null; // Reset lỗi trước khi thực hiện
    notifyListeners();
    try {
      final response = await SavingGoalService.create(request);
      if (response.success) {
        await loadGoals();
        return true;
      }
      _errorMessage = response.message; // Gán lỗi để UI hiển thị được
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi tạo mới";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGoal(int id, SavingGoalRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await SavingGoalService.update(id, request);
      if (response.success) {
        await loadGoals();
        return true;
      }
      _errorMessage = response.message; // ĐÂY LÀ CHỖ QUAN TRỌNG ĐỂ BIẾT TẠI SAO UPDATE THẤT BẠI
      return false;
    } catch (e) {
      _errorMessage = "Lỗi hệ thống khi cập nhật";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGoal(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await SavingGoalService.delete(id);
      if (response.success) {
        _goals.removeWhere((g) => g.id == id);
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

  Future<bool> depositMoney(int id, double amount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await SavingGoalService.deposit(id, amount);
      if (response.success) {
        await loadGoals();
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
}