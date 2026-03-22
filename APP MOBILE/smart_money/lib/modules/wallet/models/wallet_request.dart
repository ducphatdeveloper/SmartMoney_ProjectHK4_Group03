/// Request tạo/sửa ví gửi lên server.
/// Tương ứng: WalletRequest.java (server)
class WalletRequest {
  final String currencyCode;
  final String walletName;
  final double? balance;
  final bool? notified;
  final bool? reportable;
  final String? goalImageUrl;

  const WalletRequest({
    this.currencyCode = 'VND',
    required this.walletName,
    this.balance,
    this.notified,
    this.reportable,
    this.goalImageUrl,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'currencyCode': currencyCode,
      'walletName': walletName,
    };
    if (balance != null) map['balance'] = balance;
    if (notified != null) map['notified'] = notified;
    if (reportable != null) map['reportable'] = reportable;
    if (goalImageUrl != null) map['goalImageUrl'] = goalImageUrl;
    return map;
  }
}

