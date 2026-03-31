import '../../category/models/category_response.dart';
import '../enums/budget_type.dart';

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
  final bool isOther; //nhận biết ngân sách khác
  final BudgetType budgetType;

  // 👇 THÊM 2 FIELD NÀY: Lấy từ category chính để hiển thị icon
  final int? primaryCategoryId;
  final String? primaryCategoryIconUrl;

  final bool expired;

  final double spentAmount;
  final double remainingAmount;

  final double dailyShouldSpend;
  final double dailyActualSpend;
  final double projectedSpend;
  //new
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
    this.allCategories,
    this.repeating,
    this.categories = const [],
    this.primaryCategoryId,
    this.primaryCategoryIconUrl,
    this.expired = false,
    this.spentAmount = 0,
    this.remainingAmount = 0,
    this.dailyShouldSpend = 0,
    this.dailyActualSpend = 0,
    this.projectedSpend = 0,
    this.isOther = false,
    //new
    this.exceeded = false,
    this.warning = false,
    this.progress = 0,
    required this.budgetType
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
        primaryCategoryId: json['primaryCategoryId'] as int?,
        primaryCategoryIconUrl: json['primaryCategoryIconUrl'] as String?,
        expired: json['expired'] as bool? ?? false,
        spentAmount: (json['spentAmount'] as num?)?.toDouble() ?? 0,
        remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
        dailyShouldSpend: (json['dailyShouldSpend'] as num?)?.toDouble() ?? 0,
        dailyActualSpend: (json['dailyActualSpend'] as num?)?.toDouble() ?? 0,
        projectedSpend: (json['projectedSpend'] as num?)?.toDouble() ?? 0,

        // 🔥 NEW
        exceeded: json['exceeded'] ?? false,
        warning: json['warning'] ?? false,
        progress: (json['progress'] ?? 0).toDouble(),

        budgetType: BudgetType.values.firstWhere(
              (e) => e.name == json['budgetType'],
          orElse: () => BudgetType.custom,
        )
    );
  }
}

