import 'package:flutter/material.dart';
import '../../../core/di/setup_dependencies.dart';
import 'package:smart_money/modules/budget/models/budget_request.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/services/budget_service.dart';
import '../../transaction/models/view/transaction_response.dart';
import '../../wallet/models/wallet_response.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = getIt<BudgetService>();

  List<BudgetResponse> _budgets = [];
  bool _isLoading = false;
  List<TransactionResponse> transactions = [];
  int? _selectedWalletId;
  WalletResponse? _selectedWallet;
  String? errorMessage;
  /// Danh sách ngân sách đã hết hạn
  List<BudgetResponse> expiredBudgets = [];


  // ================= GETTER =================
  List<BudgetResponse> get budgets => _budgets;
  bool get isLoading => _isLoading;
  int? get selectedWalletId => _selectedWalletId;
  WalletResponse? get selectedWallet => _selectedWallet;


  Future<void> setWallet(WalletResponse wallet) async {
    if (_selectedWalletId == wallet.id) return; // 🔥 CHẶN RELOAD LẶP

    _selectedWallet = wallet;
    _selectedWalletId = wallet.id;

    notifyListeners(); // update UI trước

    await loadBudgets(
      walletId: wallet.id,
      forceRefresh: true,
    );
  }





  // ================= LOAD =================
  Future<void> loadBudgets({
    int? walletId,
    bool forceRefresh = false,
  }) async {
    if (walletId == null) {
      _budgets = [];
      notifyListeners();
      return;
    }

    if (!forceRefresh &&
        walletId == _selectedWalletId &&
        _budgets.isNotEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _service.getBudgets(walletId: walletId);

      if (res.success && res.data != null) {
        _budgets = res.data!.whereType<BudgetResponse>().toList();
      } else {
        _budgets = [];
      }
    } catch (e) {
      debugPrint("❌ LOAD ERROR: $e");
      _budgets = [];
    }

    _isLoading = false;
    notifyListeners();
  }



  // ================= CREATE =================
  Future<bool> createBudget(BudgetRequest request) async {
    try {
      final fixedRequest = request.copyWith(
        walletId: _selectedWalletId,
      );

      final res = await _service.create(fixedRequest);

      if (res.success && res.data != null) {
        await refreshBudgets();
        return true;
      }
    } catch (e) {
      debugPrint("❌ CREATE ERROR: $e");
    }
    return false;
  }

  // ================= UPDATE =================
  Future<bool> updateBudget(int id, BudgetRequest request) async {
    try {
      final fixedRequest = request.copyWith(
        walletId: _selectedWalletId,
      );

      final res = await _service.update(id, fixedRequest);

      if (res.success && res.data != null) {
        await refreshBudgets();
        return true;
      }
    } catch (e) {
      debugPrint("❌ UPDATE ERROR: $e");
    }
    return false;
  }

  // ================= DELETE =================
  Future<bool> deleteBudget(int id) async {
    try {
      final res = await _service.delete(id);

      if (res.success) {
        _budgets.removeWhere((b) => b.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("❌ DELETE ERROR: $e");
    }
    return false;
  }

  // ================= REFRESH =================
  Future<void> refreshBudgets() async {
    await loadBudgets(
      walletId: _selectedWalletId,
      forceRefresh: true,
    );
  }

  // ================= DISPLAY =================
  List<BudgetResponse> get displayBudgets {
    if (_budgets.isEmpty) return [];
    return _mergeOtherBudget(_budgets);
  }





// ================= REFRESH TẬP TRUNG =================
  Future<void> refreshAllData() async {
    if (_selectedWalletId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tải danh sách ngân sách mới nhất
      final res = await _service.getBudgets(walletId: _selectedWalletId!);
      if (res.success && res.data != null) {
        _budgets = res.data!.whereType<BudgetResponse>().toList();

        // 2. Sau khi có budgets, nếu cần load thêm transaction chi tiết cho từng cái
        // (Tùy thuộc logic backend của bạn, thường spentAmount đã có sẵn trong response)
        // await loadAllBudgetTransactions(walletId: _selectedWalletId!);
      }
    } catch (e) {
      debugPrint("❌ REFRESH ERROR: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Cập nhật lại UI cho toàn bộ App
    }
  }

  /// Lấy danh sách ngân sách đã hết hạn, có thể filter theo walletId
  Future<void> loadExpiredBudgets({int? walletId}) async {
    try {
      _isLoading = true;
      errorMessage = null;
      notifyListeners();

      final response = await _service.getExpired(walletId: walletId);

      if (response.success) {
        expiredBudgets = response.data ?? [];
      } else {
        expiredBudgets = [];
        errorMessage = response.message ?? "Có lỗi xảy ra khi tải dữ liệu";
      }
    } catch (e) {
      expiredBudgets = [];
      errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  // ================= MERGE OTHER =================
  List<BudgetResponse> _mergeOtherBudget(List<BudgetResponse> budgets) {
    BudgetResponse? allBudget;
    final categoryBudgets = <BudgetResponse>[];

    for (final b in budgets) {
      if (b.allCategories == true) {
        allBudget = b;
      } else {
        categoryBudgets.add(b);
      }
    }

    if (allBudget == null) return categoryBudgets;

    final totalAmount = categoryBudgets.fold(0.0, (sum, b) => sum + b.amount);
    final totalSpent = categoryBudgets.fold(0.0, (sum, b) => sum + b.spentAmount);

    final remainingAmount = (allBudget.amount - totalAmount).clamp(0.0, double.infinity);
    final remainingSpent = (allBudget.spentAmount - totalSpent).clamp(0.0, double.infinity);

    if (remainingAmount <= 0) return categoryBudgets;

    final other = BudgetResponse(
      id: -999,
      amount: remainingAmount,
      beginDate: allBudget.beginDate,
      endDate: allBudget.endDate,
      walletId: allBudget.walletId,
      walletName: allBudget.walletName,
      allCategories: false,
      repeating: false,
      categories: const [],
      primaryCategoryId: null,
      primaryCategoryIconUrl: null,
      spentAmount: remainingSpent,
      remainingAmount: (remainingAmount - remainingSpent).clamp(0.0, double.infinity),
      budgetType: allBudget.budgetType,
      isOther: true,
      exceeded: remainingSpent > remainingAmount,
      warning: remainingAmount > 0 && (remainingSpent / remainingAmount) > 0.8,
      progress: remainingAmount > 0 ? (remainingSpent / remainingAmount).clamp(0.0, 1.0) : 0.0,
    );

    return [...categoryBudgets, other];
  }
}
