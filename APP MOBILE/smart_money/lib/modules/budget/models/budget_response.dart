import '../../category/models/category_response.dart';

/// Response hiển thị thông tin ngân sách.
/// Tương ứng: BudgetResponse.java (server)
class BudgetResponse {
  final int id;
  final double amount;
  final DateTime beginDate;
  final DateTime endDate;
  final int? walletId;
  final String? walletName;
  final bool? allCategories;
  final bool? repeating;
  final List<CategoryResponse> categories;

  final bool expired;

  final double spentAmount;
  final double remainingAmount;

  final double dailyShouldSpend;
  final double dailyActualSpend;
  final double projectedSpend;

  const BudgetResponse({
    required this.id,
    required this.amount,
    required this.beginDate,
    required this.endDate,
    this.walletId,
    this.walletName,
    this.allCategories,
    this.repeating,
    this.categories = const [],
    this.expired = false,
    this.spentAmount = 0,
    this.remainingAmount = 0,
    this.dailyShouldSpend = 0,
    this.dailyActualSpend = 0,
    this.projectedSpend = 0,
  });

  factory BudgetResponse.fromJson(Map<String, dynamic> json) {
    return BudgetResponse(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      beginDate: DateTime.parse(json['beginDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      walletId: json['walletId'] as int?,
      walletName: json['walletName'] as String?,
      allCategories: json['allCategories'] as bool?,
      repeating: json['repeating'] as bool?,
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>)
              .map((e) => CategoryResponse.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      expired: json['expired'] as bool? ?? false,
      spentAmount: (json['spentAmount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
      dailyShouldSpend: (json['dailyShouldSpend'] as num?)?.toDouble() ?? 0,
      dailyActualSpend: (json['dailyActualSpend'] as num?)?.toDouble() ?? 0,
      projectedSpend: (json['projectedSpend'] as num?)?.toDouble() ?? 0,
    );
  }
}

