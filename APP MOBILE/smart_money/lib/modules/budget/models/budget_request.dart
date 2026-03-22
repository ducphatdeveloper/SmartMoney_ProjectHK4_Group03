/// Request tạo/sửa ngân sách gửi lên server.
/// Tương ứng: BudgetRequest.java (server)
class BudgetRequest {
  final double amount;
  final DateTime beginDate;
  final DateTime endDate;
  final int? walletId;
  final bool allCategories;
  final int? categoryId;
  final bool repeating;

  const BudgetRequest({
    required this.amount,
    required this.beginDate,
    required this.endDate,
    this.walletId,
    required this.allCategories,
    this.categoryId,
    required this.repeating,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'amount': amount,
      'beginDate': _formatDate(beginDate),
      'endDate': _formatDate(endDate),
      'allCategories': allCategories,
      'repeating': repeating,
    };
    if (walletId != null) map['walletId'] = walletId;
    if (categoryId != null) map['categoryId'] = categoryId;
    return map;
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

