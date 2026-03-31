import 'package:flutter/material.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';

import '../../../core/di/setup_dependencies.dart';
import '../models/budget_request.dart';
import '../services/budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = getIt<BudgetService>();

  List<BudgetResponse> budgets = [];
  bool isLoading = false;
  int? selectedWalletId;

  // ================= LOAD =================
  Future<void> loadBudgets({
    int? walletId,
    bool forceRefresh = false,
  }) async {
    // Nếu không force và wallet giống → không load lại
    if (!forceRefresh && walletId == selectedWalletId && budgets.isNotEmpty) {
      return;
    }

    isLoading = true;
    notifyListeners();

    selectedWalletId = walletId;

    try {
      debugPrint("🚀 CALL API START");

      final res = await _service.getBudgets(walletId);

      debugPrint("✅ CALL API DONE");

      if (res.success && res.data != null) {
        budgets = res.data!;
        debugPrint("✅ PROVIDER LOAD: ${budgets.length}");
      } else {
        budgets = [];
      }
    } catch (e) {
      debugPrint("❌ LOAD ERROR: $e");
      budgets = [];
    }

    isLoading = false;
    notifyListeners();
  }

  // ================= CREATE =================
  Future<bool> createBudget(BudgetRequest request) async {
    try {
      final res = await _service.create(request);

      if (res.success) {
        await loadBudgets(
          walletId: selectedWalletId,
          forceRefresh: true,
        );
        return true;
      }
    } catch (e) {
      debugPrint("❌ CREATE ERROR: $e");
    }
    return false;
  }

  // ================= DELETE =================
  Future<bool> deleteBudget(int id) async {
    try {
      final res = await _service.delete(id);

      if (res.success) {
        budgets.removeWhere((e) => e.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("❌ DELETE ERROR: $e");
    }
    return false;
  }

  //
  List<BudgetResponse> get displayBudgets {
    if (budgets.isEmpty) return [];

    // 1. Tách budget "Tất cả"
    BudgetResponse? allBudget;

    final categoryBudgets = <BudgetResponse>[];

    for (final b in budgets) {
      if (b.allCategories == true) {
        allBudget = b;
      } else {
        categoryBudgets.add(b);
      }
    }

    // 2. Nếu không có "Tất cả" → trả bình thường
    if (allBudget == null) {
      return categoryBudgets;
    }

    // 3. Tổng category
    final totalCategoryAmount = categoryBudgets.fold(
      0.0,
          (sum, b) => sum + b.amount,
    );

    final totalCategorySpent = categoryBudgets.fold(
      0.0,
          (sum, b) => sum + b.spentAmount,
    );

    // 4. Tính "Khác"
    final remainingAmount = allBudget.amount - totalCategoryAmount;
    final remainingSpent = allBudget.spentAmount - totalCategorySpent;

    // ❗ CHẶN ÂM
    if (remainingAmount < 0) {
      debugPrint("❌ Category vượt quá tổng budget");
    }

    //new
    final double spent = remainingSpent.toDouble();
    final double amount = remainingAmount.toDouble();

    final exceeded = spent > amount;

    final warning = !exceeded &&
        amount > 0 &&
        (spent / amount) > 0.8;

    final double progress = amount > 0
        ? (spent / amount).clamp(0.0, 1.0)
        : 0.0;

    final other = BudgetResponse(
      id: -999,
      amount: amount.clamp(0.0, double.infinity),
      beginDate: allBudget.beginDate,
      endDate: allBudget.endDate,
      walletId: allBudget.walletId,
      walletName: allBudget.walletName,
      allCategories: false,
      repeating: false,
      categories: const [],
      primaryCategoryId: null,
      primaryCategoryIconUrl: null,
      spentAmount: spent.clamp(0.0, double.infinity),

      // 🔥 tránh âm
      remainingAmount: (amount - spent).clamp(0.0, double.infinity),
      budgetType: allBudget.budgetType,

      isOther: true,
      exceeded: exceeded,
      warning: warning,
      progress: progress,
    );

    return [
      ...categoryBudgets,
      if (remainingAmount > 0) other, // 👉 chỉ hiển thị nếu > 0
    ];
  }

  Future<bool> updateBudget(int id, BudgetRequest request) async {
    try {
      final res = await _service.update(id, request);

      if (res.success) {
        await loadBudgets(
          walletId: selectedWalletId,
          forceRefresh: true,
        );
        return true;
      }
    } catch (e) {
      debugPrint("❌ UPDATE ERROR: $e");
    }
    return false;
  }

}