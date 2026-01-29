class WalletModel {
  final int? id;
  final int accId;
  final String currency;
  final String walletName;
  final double balance;
  final bool isNotified;
  final bool isReportable;

  WalletModel({
    this.id,
    required this.accId,
    this.currency = 'VND',
    required this.walletName,
    this.balance = 0,
    this.isNotified = true,
    this.isReportable = true,
  });

  // ===== FROM API =====
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      accId: json['acc_id'],
      currency: json['currency'],
      walletName: json['wallet_name'],
      balance: (json['balance'] as num).toDouble(),
      isNotified: json['is_notified'] == 1,
      isReportable: json['is_reportable'] == 1,
    );
  }

  // ===== TO API =====
  Map<String, dynamic> toJson() {
    return {
      'acc_id': accId,
      'currency': currency,
      'wallet_name': walletName,
      'balance': balance,
      'is_notified': isNotified ? 1 : 0,
      'is_reportable': isReportable ? 1 : 0,
    };
  }
}
