/// Response chuyển tiền.
/// Tương ứng: TransferResponse.java (server)
class TransferResponse {
  final String message;
  final double? transferredAmount;
  final double? fromWalletBalance;
  final double? toWalletBalance;

  const TransferResponse({
    required this.message,
    this.transferredAmount,
    this.fromWalletBalance,
    this.toWalletBalance,
  });

  factory TransferResponse.fromJson(Map<String, dynamic> json) {
    return TransferResponse(
      message: json['message'] as String,
      transferredAmount: json['transferredAmount'] != null 
          ? (json['transferredAmount'] as num).toDouble() 
          : null,
      fromWalletBalance: json['fromWalletBalance'] != null 
          ? (json['fromWalletBalance'] as num).toDouble() 
          : null,
      toWalletBalance: json['toWalletBalance'] != null 
          ? (json['toWalletBalance'] as num).toDouble() 
          : null,
    );
  }
}
