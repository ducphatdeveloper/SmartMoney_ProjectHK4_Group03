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
          return "This week";
        case BudgetType.monthly:
          return "This month";
        case BudgetType.yearly:
          return "This year";
        case BudgetType.custom:
          return "Custom";
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