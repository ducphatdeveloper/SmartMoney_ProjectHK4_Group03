// modules/transaction/models/view/bill_transaction_list_response.dart
// Map đúng với BillTransactionListResponse.java của Spring Boot

import 'daily_transaction_group.dart';
import '../report/transaction_total_dto.dart';

class BillTransactionListResponse {
  final int totalCount;
  final TransactionTotalDTO summary;
  final List<DailyTransactionGroup> groupedTransactions;

  const BillTransactionListResponse({
    required this.totalCount,
    required this.summary,
    required this.groupedTransactions,
  });

  factory BillTransactionListResponse.fromJson(Map<String, dynamic> json) {
    return BillTransactionListResponse(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      summary: json['summary'] != null
          ? TransactionTotalDTO.fromJson(json['summary'] as Map<String, dynamic>)
          : const TransactionTotalDTO(totalIncome: 0, totalExpense: 0),
      groupedTransactions: (json['groupedTransactions'] as List<dynamic>? ?? [])
          .map((e) => DailyTransactionGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}