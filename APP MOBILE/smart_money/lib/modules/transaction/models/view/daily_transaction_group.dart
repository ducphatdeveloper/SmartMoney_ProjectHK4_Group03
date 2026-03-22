// modules/transaction/models/view/daily_transaction_group.dart
// Map đúng với DailyTransactionGroup.java của Spring Boot
// Gom nhóm giao dịch theo ngày — dùng cho tab "Nhật ký" (VIEW)

import 'transaction_response.dart';

class DailyTransactionGroup {
  final DateTime date;
  final String displayDateLabel; // VD: "Hôm nay", "Hôm qua", "Thứ Sáu, 14/03"
  final double netAmount;        // Tổng thu/chi ròng của ngày
  final List<TransactionResponse> transactions;

  const DailyTransactionGroup({
    required this.date,
    required this.displayDateLabel,
    required this.netAmount,
    required this.transactions,
  });

  factory DailyTransactionGroup.fromJson(Map<String, dynamic> json) {
    return DailyTransactionGroup(
      date: DateTime.parse(json['date'] as String),
      displayDateLabel: json['displayDateLabel'] as String,
      netAmount: (json['netAmount'] as num).toDouble(),
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => TransactionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

