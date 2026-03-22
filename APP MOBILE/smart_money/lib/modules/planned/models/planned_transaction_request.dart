/// Request tạo/sửa giao dịch lặp lại gửi lên server.
/// Tương ứng: PlannedTransactionRequest.java (server)
class PlannedTransactionRequest {
  final int walletId;
  final double amount;
  final int categoryId;
  final int? debtId;
  final String? note;
  final int planType;
  final int repeatType;
  final int repeatInterval;
  final int? repeatOnDayVal;
  final DateTime beginDate;
  final String endDateOption;
  final DateTime? endDateValue;
  final int? repeatCount;

  const PlannedTransactionRequest({
    required this.walletId,
    required this.amount,
    required this.categoryId,
    this.debtId,
    this.note,
    required this.planType,
    required this.repeatType,
    required this.repeatInterval,
    this.repeatOnDayVal,
    required this.beginDate,
    required this.endDateOption,
    this.endDateValue,
    this.repeatCount,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'walletId': walletId,
      'amount': amount,
      'categoryId': categoryId,
      'planType': planType,
      'repeatType': repeatType,
      'repeatInterval': repeatInterval,
      'beginDate': _formatDate(beginDate),
      'endDateOption': endDateOption,
    };
    if (debtId != null) map['debtId'] = debtId;
    if (note != null) map['note'] = note;
    if (repeatOnDayVal != null) map['repeatOnDayVal'] = repeatOnDayVal;
    if (endDateValue != null) map['endDateValue'] = _formatDate(endDateValue!);
    if (repeatCount != null) map['repeatCount'] = repeatCount;
    return map;
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

