/// Request tạo/sửa mục tiêu tiết kiệm gửi lên server.
/// Tương ứng: SavingGoalRequest.java (server)
class SavingGoalRequest {
  final String goalName;
  final double targetAmount;
  final double? initialAmount;
  final String currencyCode;
  final DateTime endDate;
  final String? goalImageUrl;
  final bool? notified;
  final bool? reportable;
  final double? amount;

  const SavingGoalRequest({
    required this.goalName,
    required this.targetAmount,
    this.initialAmount,
    this.currencyCode = 'VND',
    required this.endDate,
    this.goalImageUrl,
    this.notified,
    this.reportable,
    this.amount,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'goalName': goalName,
      'targetAmount': targetAmount,
      'currencyCode': currencyCode,
      'endDate': _formatDate(endDate),
    };
    if (initialAmount != null) map['initialAmount'] = initialAmount;
    if (goalImageUrl != null) map['goalImageUrl'] = goalImageUrl;
    if (notified != null) map['notified'] = notified;
    if (reportable != null) map['reportable'] = reportable;
    if (amount != null) map['amount'] = amount;
    return map;
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

