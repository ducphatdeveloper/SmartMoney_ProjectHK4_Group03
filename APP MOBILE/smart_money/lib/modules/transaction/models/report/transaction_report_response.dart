// modules/transaction/models/report/transaction_report_response.dart
// Map đúng với TransactionReportResponse.java của Spring Boot
// Tổng quan báo cáo tài chính theo kỳ (REPORT)

import '../view/transaction_response.dart';

class TransactionReportResponse {
  final double openingBalance;   // Số dư đầu kỳ
  final double closingBalance;   // Số dư cuối kỳ
  final double totalIncome;      // Tổng tiền thu vào
  final double totalExpense;     // Tổng tiền chi ra
  final double netIncome;        // Thu nhập ròng (Thu - Chi)
  final int debtTransactionCount;  // Số giao dịch Nợ (Đi vay, Trả nợ)
  final int loanTransactionCount;  // Số giao dịch Cho vay (Cho vay, Thu nợ)
  final List<TransactionResponse>? transactions;

  const TransactionReportResponse({
    required this.openingBalance,
    required this.closingBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.netIncome,
    required this.debtTransactionCount,
    required this.loanTransactionCount,
    this.transactions,
  });

  factory TransactionReportResponse.fromJson(Map<String, dynamic> json) {
    return TransactionReportResponse(
      openingBalance: (json['openingBalance'] as num).toDouble(),
      closingBalance: (json['closingBalance'] as num).toDouble(),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
      netIncome: (json['netIncome'] as num).toDouble(),
      debtTransactionCount: json['debtTransactionCount'] as int? ?? 0,
      loanTransactionCount: json['loanTransactionCount'] as int? ?? 0,
      transactions: json['transactions'] != null
          ? (json['transactions'] as List<dynamic>)
              .map((e) => TransactionResponse.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}

