import 'package:flutter/material.dart';

enum BudgetType {
  weekly,
  monthly,
  yearly,
  custom,
}

extension BudgetTypeExtension on BudgetType {
  String get label {
    switch (this) {
      case BudgetType.weekly:
        return "Tuần này";
      case BudgetType.monthly:
        return "Tháng này";
      case BudgetType.yearly:
        return "Năm nay";
      case BudgetType.custom:
        return "Tuỳ chỉnh";
    }
  }
}
