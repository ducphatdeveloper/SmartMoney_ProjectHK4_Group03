import 'package:flutter/material.dart';

import '../enums/budget_type.dart';

class BudgetRequest {


  final double amount;
  final DateTime beginDate;
  final DateTime endDate;
  final int? walletId;
  final bool allCategories;
  final int? categoryId;
  final bool repeating;
  final String budgetType;

  const BudgetRequest({
    required this.amount,
    required this.beginDate,
    required this.endDate,
    this.walletId,
    required this.allCategories,
    this.categoryId,
    required this.repeating,
    required this.budgetType,
  });

  // ================= JSON =================
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,

      /// 🔥 FORMAT DATE CHUẨN BACKEND
      'beginDate': _formatDate(beginDate),
      'endDate': _formatDate(endDate),

      'allCategories': allCategories,
      'repeating': repeating,

      /// 🔥 LUÔN ĐẢM BẢO UPPERCASE
      'budgetType': budgetType.toUpperCase(),

      if (walletId != null) 'walletId': walletId,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }

  // ================= FORMAT DATE =================
  static String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
  }

  // ================= HELPER TẠO NHANH =================
    factory BudgetRequest.fromUI({
      required double amount,
      required DateTimeRange range,
      required bool repeating,
      required bool allCategories,
      required int? walletId,
      required int? categoryId,
      required BudgetType type,
    }) {
      return BudgetRequest(
        amount: amount,
        beginDate: range.start,
        endDate: range.end,
        walletId: walletId,
        categoryId: categoryId,
        repeating: repeating,
        allCategories: allCategories,
        budgetType: type.apiValue, // 🔥 dùng extension
      );
    }

  BudgetRequest copyWith({
    double? amount,
    DateTime? beginDate,
    DateTime? endDate,
    int? walletId,
    bool? allCategories,
    int? categoryId,
    bool? repeating,
    String? budgetType,
  }) {
    return BudgetRequest(
      amount: amount ?? this.amount,
      beginDate: beginDate ?? this.beginDate,
      endDate: endDate ?? this.endDate,
      walletId: walletId ?? this.walletId,
      allCategories: allCategories ?? this.allCategories,
      categoryId: categoryId ?? this.categoryId,
      repeating: repeating ?? this.repeating,
      budgetType: budgetType ?? this.budgetType,
    );
  }

}

