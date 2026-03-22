// modules/transaction/models/request/transaction_search_request.dart
// Map đúng với TransactionSearchRequest.java của Spring Boot
// Dùng để tìm kiếm/lọc giao dịch (REQUEST)

class TransactionSearchRequest {
  final double? minAmount;
  final double? maxAmount;
  final int? walletId;
  final int? savingGoalId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;
  final List<int>? categoryIds;
  final String? withPerson;

  const TransactionSearchRequest({
    this.minAmount,
    this.maxAmount,
    this.walletId,
    this.savingGoalId,
    this.startDate,
    this.endDate,
    this.note,
    this.categoryIds,
    this.withPerson,
  });

  /// Chuyển sang JSON để gửi lên server
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (minAmount != null) map['minAmount'] = minAmount;
    if (maxAmount != null) map['maxAmount'] = maxAmount;
    if (walletId != null) map['walletId'] = walletId;
    if (savingGoalId != null) map['savingGoalId'] = savingGoalId;
    if (startDate != null) map['startDate'] = startDate!.toIso8601String();
    if (endDate != null) map['endDate'] = endDate!.toIso8601String();
    if (note != null) map['note'] = note;
    if (categoryIds != null) map['categoryIds'] = categoryIds;
    if (withPerson != null) map['withPerson'] = withPerson;
    return map;
  }
}

