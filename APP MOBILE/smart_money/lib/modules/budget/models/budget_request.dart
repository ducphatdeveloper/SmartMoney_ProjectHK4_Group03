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

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,

      // 🔥 đảm bảo format đúng ISO backend thích
      'beginDate': _formatDate(beginDate),
      'endDate': _formatDate(endDate),

      'allCategories': allCategories,
      'repeating': repeating,
      'budgetType': budgetType, // WEEKLY / MONTHLY / YEARLY / CUSTOM

      if (walletId != null) 'walletId': walletId,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }

  static String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
  }
}