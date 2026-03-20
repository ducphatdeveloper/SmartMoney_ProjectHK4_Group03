class WalletModel {
  final int? id;
  final String walletName;
  final double balance;
  final String currencyCode;
  final bool notified;
  final bool reportable;
  final String? goalImageUrl;

  WalletModel({
    this.id,
    required this.walletName,
    required this.balance,
    required this.currencyCode,
    this.notified = true,
    this.reportable = true,
    this.goalImageUrl,
  });

  // ===== FROM API =====
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      walletName: json['walletName'],
      balance: (json['balance'] as num).toDouble(),
      currencyCode: json['currencyCode'],
      notified: json['notified'],
      reportable: json['reportable'],
      goalImageUrl: json['goalImageUrl'],
    );
  }

  // ===== TO API =====
  Map<String, dynamic> toJson() {
    return {
      "walletName": walletName,
      "currencyCode": currencyCode,
      "balance": balance,
      "notified": notified,
      "reportable": reportable,
      "goalImageUrl": goalImageUrl,
    };
  }
}
