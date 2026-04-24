// modules/transaction/models/request/transaction_request.dart
// Map đúng với TransactionRequest.java của Spring Boot
// Gửi lên server khi tạo hoặc cập nhật giao dịch (REQUEST)

class TransactionRequest {
  final int? walletId;
  final int? goalId;
  final String amount; // Đổi từ double sang String để tránh precision error
  final int categoryId;
  final String? note;
  final DateTime transDate;
  final String? withPerson;
  final int? eventId;
  final DateTime? reminderDate;
  final bool reportable;
  final String? personName;   // Chỉ dùng khi category = Cho vay / Đi vay
  final int? debtId;          // Chỉ dùng khi category = Trả nợ / Thu nợ
  final DateTime? dueDate;    // Chỉ dùng khi tạo khoản nợ mới từ giao dịch
  final int? sourceType;      // 1=manual|2=chat|3=voice|4=receipt|5=planned
  final int? aiChatId;        // NULL nếu manual, NOT NULL nếu sourceType 2/3/4

  const TransactionRequest({
    this.walletId,
    this.goalId,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.transDate,
    this.withPerson,
    this.eventId,
    this.reminderDate,
    required this.reportable,
    this.personName,
    this.debtId,
    this.dueDate,
    this.sourceType,
    this.aiChatId,
  });

  /// Chuyển sang JSON để gửi lên server
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'amount': amount,
      'categoryId': categoryId,
      'transDate': transDate.toIso8601String(),
      'reportable': reportable,
    };
    if (walletId != null) map['walletId'] = walletId;
    if (goalId != null) map['goalId'] = goalId;
    if (note != null) map['note'] = note;
    if (withPerson != null) map['withPerson'] = withPerson;
    if (eventId != null) map['eventId'] = eventId;
    if (reminderDate != null) map['reminderDate'] = reminderDate!.toIso8601String();
    if (personName != null) map['personName'] = personName;
    if (debtId != null) map['debtId'] = debtId;
    if (dueDate != null) map['dueDate'] = dueDate!.toIso8601String();
    if (sourceType != null) map['sourceType'] = sourceType;
    if (aiChatId != null) map['aiChatId'] = aiChatId;
    return map;
  }
}

