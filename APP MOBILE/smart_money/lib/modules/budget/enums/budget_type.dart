  import 'package:flutter/material.dart';

  enum BudgetType {
    weekly,
    monthly,
    yearly,
    custom,
  }

  extension BudgetTypeExtension on BudgetType {
    // =========================
    // LABEL HIỂN THỊ
    // =========================
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

    // =========================
    // VALUE GỬI API
    // =========================
    String get apiValue {
      return name.toUpperCase(); // weekly -> WEEKLY
    }

    // =========================
    // PARSE TỪ API VỀ
    // =========================
    static BudgetType fromString(String? value) {
      switch (value?.toUpperCase()) {
        case 'WEEKLY':
          return BudgetType.weekly;
        case 'MONTHLY':
          return BudgetType.monthly;
        case 'YEARLY':
          return BudgetType.yearly;
        default:
          return BudgetType.custom;
      }
    }
  }