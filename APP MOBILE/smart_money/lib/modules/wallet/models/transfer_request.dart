/// Request chuyển tiền giữa các ví.
/// Tương ứng: TransferRequest.java (server)
class TransferRequest {
  final int fromWalletId;
  final int toWalletId;
  final double amount;

  const TransferRequest({
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'amount': amount,
    };
  }
}
