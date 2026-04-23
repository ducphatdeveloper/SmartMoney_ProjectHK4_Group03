import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';

import '../../category/models/category_response.dart';
import '../enums/budget_type.dart';

class BudgetResponse {
  final int id;
  final double amount;
  final DateTime beginDate;
  final DateTime endDate;
  final int? walletId;
  final String? walletName;
  final bool allCategories;
  final bool repeating;
  final List<CategoryResponse> categories;
  final bool isOther;
  final BudgetType budgetType;

  final int? primaryCategoryId;
  final String? primaryCategoryIconUrl;

  final bool expired;

  final double spentAmount;
  final double remainingAmount;

  final double dailyShouldSpend;
  final double dailyActualSpend;
  final double projectedSpend;

  final double suggestedAmount;       // Ngân sách đề xuất dựa trên lịch sử 3 tháng
  final double suggestedDailySpend;   // Nên chi hàng ngày theo đề xuất
  final double? suggestedWeeklySpend;  // Nên chi hàng tuần theo đề xuất (chỉ có giá trị khi budgetType=WEEKLY)
  final double? suggestedMonthlySpend; // Nên chi hàng tháng theo đề xuất (chỉ có giá trị khi budgetType=MONTHLY)
  final double? suggestedYearlySpend;  // Nên chi hàng năm theo đề xuất (chỉ có giá trị khi budgetType=YEARLY)
  final double? suggestedCustomSpend;  // Nên chi theo custom period theo đề xuất (chỉ có giá trị khi budgetType=CUSTOM)
  final double overBudgetAmount;      // Số tiền vượt ngân sách = max(0, spent - amount)

  final bool exceeded;
  final bool warning;
  final double progress;

  const BudgetResponse({
    required this.id,
    required this.amount,
    required this.beginDate,
    required this.endDate,
    this.walletId,
    this.walletName,
    this.allCategories = false,
    this.repeating = false,
    this.categories = const [],
    this.primaryCategoryId,
    this.primaryCategoryIconUrl,
    this.expired = false,
    this.spentAmount = 0,
    this.remainingAmount = 0,
    this.dailyShouldSpend = 0,
    this.dailyActualSpend = 0,
    this.projectedSpend = 0,
    this.suggestedAmount = 0,
    this.suggestedDailySpend = 0,
    this.suggestedWeeklySpend,
    this.suggestedMonthlySpend,
    this.suggestedYearlySpend,
    this.suggestedCustomSpend,
    this.overBudgetAmount = 0,
    this.isOther = false,
    this.exceeded = false,
    this.warning = false,
    this.progress = 0,
    required this.budgetType,
  });

  /// Factory parse từ JSON
  factory BudgetResponse.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final List<CategoryResponse> safeCategories = (rawCategories is List)
        ? rawCategories
        .where((e) => e != null)
        .map((e) => CategoryResponse.fromJson(e as Map<String, dynamic>))
        .toList()
        : [];

    DateTime safeParseDate(String? value) {
      if (value == null || value.isEmpty) return DateTime.now();
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    bool safeBool(dynamic v) => v == true;

    double safeDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return BudgetResponse(
      id: json['id'] ?? 0,
      amount: safeDouble(json['amount']),
      beginDate: safeParseDate(json['beginDate']),
      endDate: safeParseDate(json['endDate']),
      walletId: json['walletId'],
      walletName: json['walletName'],
      allCategories: safeBool(json['allCategories']),
      repeating: safeBool(json['repeating']),
      categories: safeCategories,
      primaryCategoryId: json['primaryCategoryId'],
      primaryCategoryIconUrl: json['primaryCategoryIconUrl'],
      expired: safeBool(json['expired']),
      spentAmount: safeDouble(json['spentAmount']),
      suggestedAmount: safeDouble(json['suggestedAmount']),
      suggestedDailySpend: safeDouble(json['suggestedDailySpend']),
      suggestedWeeklySpend: safeDouble(json['suggestedWeeklySpend']),
      suggestedMonthlySpend: safeDouble(json['suggestedMonthlySpend']),
      suggestedYearlySpend: safeDouble(json['suggestedYearlySpend']),
      suggestedCustomSpend: safeDouble(json['suggestedCustomSpend']),
      overBudgetAmount: safeDouble(json['overBudgetAmount']),
      remainingAmount: safeDouble(json['remainingAmount']),
      dailyShouldSpend: safeDouble(json['dailyShouldSpend']),
      dailyActualSpend: safeDouble(json['dailyActualSpend']),
      projectedSpend: safeDouble(json['projectedSpend']),
      exceeded: safeBool(json['exceeded']),
      warning: safeBool(json['warning']),
      progress: safeDouble(json['progress']),
      budgetType: BudgetTypeExtension.fromString(json['budgetType']),
      isOther: false,
    );
  }

  /// CopyWith duy nhất, đầy đủ tất cả trường
  BudgetResponse copyWith({
    double? amount,
    DateTime? beginDate,
    DateTime? endDate,
    List<CategoryResponse>? categories,
    bool? repeating,
    int? walletId,
    String? walletName,
    String? primaryCategoryIconUrl,
    bool? allCategories,
    bool? expired,
    double? spentAmount,
    double? remainingAmount,
    double? dailyShouldSpend,
    double? dailyActualSpend,
    double? projectedSpend,
    double? suggestedAmount,
    double? suggestedDailySpend,
    double? suggestedWeeklySpend,
    double? suggestedMonthlySpend,
    double? suggestedYearlySpend,
    double? suggestedCustomSpend,
    double? overBudgetAmount,
    bool? exceeded,
    bool? warning,
    double? progress,
    BudgetType? budgetType,
    bool? isOther,

  }) {
    return BudgetResponse(
      id: id,
      amount: amount ?? this.amount,
      beginDate: beginDate ?? this.beginDate,
      endDate: endDate ?? this.endDate,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      allCategories: allCategories ?? this.allCategories,
      repeating: repeating ?? this.repeating,
      categories: categories ?? this.categories,
      primaryCategoryId: primaryCategoryId,
      primaryCategoryIconUrl: primaryCategoryIconUrl ?? this.primaryCategoryIconUrl,
      expired: expired ?? this.expired,
      spentAmount: spentAmount ?? this.spentAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      dailyShouldSpend: dailyShouldSpend ?? this.dailyShouldSpend,
      dailyActualSpend: dailyActualSpend ?? this.dailyActualSpend,
      projectedSpend: projectedSpend ?? this.projectedSpend,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      suggestedDailySpend: suggestedDailySpend ?? this.suggestedDailySpend,
      suggestedWeeklySpend: suggestedWeeklySpend ?? this.suggestedWeeklySpend,
      suggestedMonthlySpend: suggestedMonthlySpend ?? this.suggestedMonthlySpend,
      suggestedYearlySpend: suggestedYearlySpend ?? this.suggestedYearlySpend,
      suggestedCustomSpend: suggestedCustomSpend ?? this.suggestedCustomSpend,
      overBudgetAmount: overBudgetAmount ?? this.overBudgetAmount,
      exceeded: exceeded ?? this.exceeded,
      warning: warning ?? this.warning,
      progress: progress ?? this.progress,
      budgetType: budgetType ?? this.budgetType,
      isOther: isOther ?? this.isOther,
    );
  }
}
