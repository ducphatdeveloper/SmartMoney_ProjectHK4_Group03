/// Response tổng số dư tất cả ví.
/// Tương ứng: TotalBalanceResponse.java (server)
class TotalBalanceResponse {
  final double totalBalance;

  const TotalBalanceResponse({required this.totalBalance});

  factory TotalBalanceResponse.fromJson(Map<String, dynamic> json) {
    return TotalBalanceResponse(
      totalBalance: (json['totalBalance'] as num).toDouble(),
    );
  }
}
