class SavingGoalModel {
  final int? id;
  final int accId;
  final String currency;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final String? goalImageUrl;
  final DateTime beginDate;
  final DateTime endDate;
  final int status;
  final bool isNotified;
  final bool isReportable;
  final bool isFinished;

  SavingGoalModel({
    this.id,
    required this.accId,
    this.currency = 'VND',
    required this.goalName,
    required this.targetAmount,
    this.currentAmount = 0,
    this.goalImageUrl,
    required this.beginDate,
    required this.endDate,
    this.status = 1,
    this.isNotified = true,
    this.isReportable = true,
    this.isFinished = false,
  });

  factory SavingGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingGoalModel(
      id: json['id'],
      accId: json['acc_id'],
      currency: json['currency'],
      goalName: json['goal_name'],
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      goalImageUrl: json['goal_image_url'],
      beginDate: DateTime.parse(json['begin_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['is_status'],
      isNotified: json['is_notified'] == 1,
      isReportable: json['is_reportable'] == 1,
      isFinished: json['is_finished'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'acc_id': accId,
      'currency': currency,
      'goal_name': goalName,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'goal_image_url': goalImageUrl,
      'begin_date': beginDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_status': status,
      'is_notified': isNotified ? 1 : 0,
      'is_reportable': isReportable ? 1 : 0,
      'is_finished': isFinished ? 1 : 0,
    };
  }
}
