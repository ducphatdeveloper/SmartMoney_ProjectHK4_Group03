/// Response hiển thị thông tin mục tiêu tiết kiệm.
/// Tương ứng: SavingGoalResponse.java (server)
class SavingGoalResponse {
  final int id;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final DateTime? beginDate;
  final DateTime endDate;
  final int? goalStatus;
  final bool? notified;
  final bool? reportable;
  final bool? finished;
  final String? currencyCode;
  final String? imageUrl;
  final double remainingAmount;
  final double? progressPercent;

  const SavingGoalResponse({
    required this.id,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    this.beginDate,
    required this.endDate,
    this.goalStatus,
    this.notified,
    this.reportable,
    this.finished,
    this.currencyCode,
    this.imageUrl,
    this.remainingAmount = 0,
    this.progressPercent,
  });

  factory SavingGoalResponse.fromJson(Map<String, dynamic> json) {
    return SavingGoalResponse(
      id: json['id'] as int,
      goalName: json['goalName'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      beginDate: json['beginDate'] != null
          ? DateTime.parse(json['beginDate'] as String)
          : null,
      endDate: DateTime.parse(json['endDate'] as String),
      goalStatus: json['goalStatus'] as int?,
      notified: json['notified'] as bool?,
      reportable: json['reportable'] as bool?,
      finished: json['finished'] as bool?,
      currencyCode: json['currencyCode'] as String?,
      imageUrl: json['imageUrl'] as String?,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble(),
    );
  }
}

