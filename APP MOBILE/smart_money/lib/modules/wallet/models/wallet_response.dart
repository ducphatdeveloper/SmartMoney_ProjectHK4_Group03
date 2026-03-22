/// Response hiển thị thông tin ví.
/// Tương ứng: WalletResponse.java (server)
class WalletResponse {
  final int id;
  final String walletName;
  final double balance;
  final String? currencyCode;
  final bool? notified;
  final bool? reportable;
  final String? goalImageUrl;

  const WalletResponse({
    required this.id,
    required this.walletName,
    required this.balance,
    this.currencyCode,
    this.notified,
    this.reportable,
    this.goalImageUrl,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    return WalletResponse(
      id: json['id'] as int,
      walletName: json['walletName'] as String,
      balance: (json['balance'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String?,
      notified: json['notified'] as bool?,
      reportable: json['reportable'] as bool?,
      goalImageUrl: json['goalImageUrl'] as String?,
    );
  }
}

