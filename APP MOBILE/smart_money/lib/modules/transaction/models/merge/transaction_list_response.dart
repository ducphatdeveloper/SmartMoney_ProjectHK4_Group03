// modules/transaction/models/merge/transaction_list_response.dart
// Map đúng với TransactionListResponse.java của Spring Boot

import '../view/daily_transaction_group.dart';

class TransactionListResponse {
  final double totalIncome;    // Tổng thu
  final double totalExpense;   // Tổng chi
  final double netAmount;      // Số dư ròng (Thu - Chi)
  final int transactionCount;  // Tổng số lượng giao dịch
  final List<DailyTransactionGroup> dailyGroups; // Danh sách nhóm theo ngày

  const TransactionListResponse({
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
    required this.transactionCount,
    required this.dailyGroups,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    return TransactionListResponse(
      totalIncome: (json['totalIncome'] as num? ?? 0).toDouble(),
      totalExpense: (json['totalExpense'] as num? ?? 0).toDouble(),
      netAmount: (json['netAmount'] as num? ?? 0).toDouble(),
      transactionCount: json['transactionCount'] as int? ?? 0,
      dailyGroups: json['dailyGroups'] != null
          ? (json['dailyGroups'] as List<dynamic>)
          .map((e) => DailyTransactionGroup.fromJson(e as Map<String, dynamic>))
          .toList()
          : [],
    );
  }
}