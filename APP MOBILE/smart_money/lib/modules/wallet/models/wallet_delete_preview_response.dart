import 'package:smart_money/modules/wallet/models/wallet_response.dart';

/// Response preview trước khi xóa ví.
/// Tương ứng: WalletDeletePreviewResponse.java (server)
class WalletDeletePreviewResponse {
  final WalletResponse wallet;
  final List<BudgetResponse> relatedBudgets;
  final int transactionCount;
  final List<WalletResponse> otherWallets;
  final double currentBalance;

  const WalletDeletePreviewResponse({
    required this.wallet,
    required this.relatedBudgets,
    required this.transactionCount,
    required this.otherWallets,
    required this.currentBalance,
  });

  factory WalletDeletePreviewResponse.fromJson(Map<String, dynamic> json) {
    return WalletDeletePreviewResponse(
      wallet: WalletResponse.fromJson(json['wallet']),
      relatedBudgets: (json['relatedBudgets'] as List)
          .map((e) => BudgetResponse.fromJson(e))
          .toList(),
      transactionCount: json['transactionCount'] as int,
      otherWallets: (json['otherWallets'] as List)
          .map((e) => WalletResponse.fromJson(e))
          .toList(),
      currentBalance: (json['currentBalance'] as num).toDouble(),
    );
  }
}

/// Response ngân sách
/// Tương ứng: BudgetResponse.java (server)
class BudgetResponse {
  final int? id;
  final double? amount;
  final String? beginDate;
  final String? endDate;
  final int? walletId;
  final String? walletName;
  final bool? allCategories;
  final bool? repeating;
  final String? budgetType;

  const BudgetResponse({
    this.id,
    this.amount,
    this.beginDate,
    this.endDate,
    this.walletId,
    this.walletName,
    this.allCategories,
    this.repeating,
    this.budgetType,
  });

  factory BudgetResponse.fromJson(Map<String, dynamic> json) {
    return BudgetResponse(
      id: json['id'] as int?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      beginDate: json['beginDate'] as String?,
      endDate: json['endDate'] as String?,
      walletId: json['walletId'] as int?,
      walletName: json['walletName'] as String?,
      allCategories: json['allCategories'] as bool?,
      repeating: json['repeating'] as bool?,
      budgetType: json['budgetType'] as String?,
    );
  }
}
