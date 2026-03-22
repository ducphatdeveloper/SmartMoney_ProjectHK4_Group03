// modules/transaction/models/report/transaction_total_dto.dart
// Map đúng với TransactionTotalDTO.java của Spring Boot
// Kết quả tính tổng thu và tổng chi đơn giản (REPORT)
// Lưu ý: DTO này chủ yếu dùng bên server cho query GROUP BY,
// Flutter có thể không cần dùng trực tiếp nhưng giữ để đồng bộ DTO.

class TransactionTotalDTO {
  final double totalIncome;
  final double totalExpense;

  const TransactionTotalDTO({
    required this.totalIncome,
    required this.totalExpense,
  });

  factory TransactionTotalDTO.fromJson(Map<String, dynamic> json) {
    return TransactionTotalDTO(
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

