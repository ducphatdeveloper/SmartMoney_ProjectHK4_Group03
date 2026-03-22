// modules/transaction/models/report/financial_report_response.dart
// Map đúng với FinancialReportResponse.java của Spring Boot
// Tổng hợp cho màn hình Dashboard "All-in-One" (REPORT)

import 'transaction_report_response.dart';
import 'category_report_dto.dart';

class FinancialReportResponse {
  final TransactionReportResponse summary;     // Tổng quan tài chính trong kỳ
  final double totalCurrentBalance;             // Tổng tài sản hiện tại (tất cả ví)
  final List<CategoryReportDTO> expenseCategories; // Chi tiết biểu đồ Chi
  final List<CategoryReportDTO> incomeCategories;  // Chi tiết biểu đồ Thu

  const FinancialReportResponse({
    required this.summary,
    required this.totalCurrentBalance,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  factory FinancialReportResponse.fromJson(Map<String, dynamic> json) {
    return FinancialReportResponse(
      summary: TransactionReportResponse.fromJson(
          json['summary'] as Map<String, dynamic>),
      totalCurrentBalance: (json['totalCurrentBalance'] as num).toDouble(),
      expenseCategories: (json['expenseCategories'] as List<dynamic>)
          .map((e) => CategoryReportDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      incomeCategories: (json['incomeCategories'] as List<dynamic>)
          .map((e) => CategoryReportDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

