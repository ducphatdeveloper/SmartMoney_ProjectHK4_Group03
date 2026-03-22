// modules/transaction/models/view/category_transaction_group.dart
// Map đúng với CategoryTransactionGroup.java của Spring Boot
// Gom nhóm giao dịch theo danh mục — dùng cho tab "Danh mục" (VIEW)

import 'transaction_response.dart';

class CategoryTransactionGroup {
  final int categoryId;
  final String categoryName;
  final String? categoryIconUrl;
  final bool? categoryType;       // true: Thu, false: Chi
  final double totalAmount;
  final int transactionCount;
  final List<TransactionResponse> transactions;

  const CategoryTransactionGroup({
    required this.categoryId,
    required this.categoryName,
    this.categoryIconUrl,
    this.categoryType,
    required this.totalAmount,
    required this.transactionCount,
    required this.transactions,
  });

  factory CategoryTransactionGroup.fromJson(Map<String, dynamic> json) {
    return CategoryTransactionGroup(
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String,
      categoryIconUrl: json['categoryIconUrl'] as String?,
      categoryType: json['categoryType'] as bool?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => TransactionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

