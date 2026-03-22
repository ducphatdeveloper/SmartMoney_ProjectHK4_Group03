/// Response hiển thị thông tin giao dịch lặp lại.
/// Tương ứng: PlannedTransactionResponse.java (server)
class PlannedTransactionResponse {
  final int id;

  final int? walletId;
  final String? walletName;

  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final bool? categoryType;

  final int? debtId;
  final String? debtPersonName;

  final String? note;
  final double amount;

  final int planType;

  final int? repeatType;
  final int? repeatInterval;
  final int? repeatOnDayVal;

  final DateTime? beginDate;
  final DateTime? nextDueDate;
  final DateTime? lastExecutedAt;
  final DateTime? endDate;

  final bool? active;
  final DateTime? createdAt;

  final String? repeatDescription;

  const PlannedTransactionResponse({
    required this.id,
    this.walletId,
    this.walletName,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryType,
    this.debtId,
    this.debtPersonName,
    this.note,
    required this.amount,
    required this.planType,
    this.repeatType,
    this.repeatInterval,
    this.repeatOnDayVal,
    this.beginDate,
    this.nextDueDate,
    this.lastExecutedAt,
    this.endDate,
    this.active,
    this.createdAt,
    this.repeatDescription,
  });

  factory PlannedTransactionResponse.fromJson(Map<String, dynamic> json) {
    return PlannedTransactionResponse(
      id: json['id'] as int,
      walletId: json['walletId'] as int?,
      walletName: json['walletName'] as String?,
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      categoryIcon: json['categoryIcon'] as String?,
      categoryType: json['categoryType'] as bool?,
      debtId: json['debtId'] as int?,
      debtPersonName: json['debtPersonName'] as String?,
      note: json['note'] as String?,
      amount: (json['amount'] as num).toDouble(),
      planType: json['planType'] as int,
      repeatType: json['repeatType'] as int?,
      repeatInterval: json['repeatInterval'] as int?,
      repeatOnDayVal: json['repeatOnDayVal'] as int?,
      beginDate: json['beginDate'] != null
          ? DateTime.parse(json['beginDate'] as String)
          : null,
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      active: json['active'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      repeatDescription: json['repeatDescription'] as String?,
    );
  }
}

