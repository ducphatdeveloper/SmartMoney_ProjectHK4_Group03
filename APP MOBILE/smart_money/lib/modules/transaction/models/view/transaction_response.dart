// modules/transaction/models/view/transaction_response.dart
// Map đúng với TransactionResponse.java của Spring Boot
// Đây là DTO hiển thị thông tin một giao dịch (VIEW)

class TransactionResponse {
  final int id;
  final double amount;
  final String? note;
  final DateTime transDate;
  final String? withPerson;
  final bool reportable;
  final int sourceType; // 1: manual | 2: chat | 3: voice | 4: receipt | 5: planned

  // --- Dữ liệu join từ các bảng liên quan ---
  final int? walletId;
  final String? walletName;
  final String? walletIconUrl;

  final int? categoryId;
  final String? categoryName;
  final String? categoryIconUrl;
  final bool categoryType; // true: Thu, false: Chi

  final int? eventId;
  final String? eventName;

  final int? debtId;

  final int? savingGoalId;
  final String? savingGoalName;
  final String? savingGoalIconUrl;

  final int? aiChatId;

  const TransactionResponse({
    required this.id,
    required this.amount,
    this.note,
    required this.transDate,
    this.withPerson,
    required this.reportable,
    required this.sourceType,
    this.walletId,
    this.walletName,
    this.walletIconUrl,
    this.categoryId,
    this.categoryName,
    this.categoryIconUrl,
    required this.categoryType,
    this.eventId,
    this.eventName,
    this.debtId,
    this.savingGoalId,
    this.savingGoalName,
    this.savingGoalIconUrl,
    this.aiChatId,
  });

  /// Parse từ JSON server trả về
  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      transDate: DateTime.parse(json['transDate'] as String),
      withPerson: json['withPerson'] as String?,
      reportable: json['reportable'] as bool,
      sourceType: json['sourceType'] as int? ?? 1,
      walletId: json['walletId'] as int?,
      walletName: json['walletName'] as String?,
      walletIconUrl: json['walletIconUrl'] as String?,
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      categoryIconUrl: json['categoryIconUrl'] as String?,
      categoryType: json['categoryType'] as bool? ?? false,
      eventId: json['eventId'] as int?,
      eventName: json['eventName'] as String?,
      debtId: json['debtId'] as int?,
      savingGoalId: json['savingGoalId'] as int?,
      savingGoalName: json['savingGoalName'] as String?,
      savingGoalIconUrl: json['savingGoalIconUrl'] as String?,
      aiChatId: json['aiChatId'] as int?,
    );
  }

  /// Chuyển sang JSON (dùng khi cần cache local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'transDate': transDate.toIso8601String(),
      'withPerson': withPerson,
      'reportable': reportable,
      'sourceType': sourceType,
      'walletId': walletId,
      'walletName': walletName,
      'walletIconUrl': walletIconUrl,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryIconUrl': categoryIconUrl,
      'categoryType': categoryType,
      'eventId': eventId,
      'eventName': eventName,
      'debtId': debtId,
      'savingGoalId': savingGoalId,
      'savingGoalName': savingGoalName,
      'savingGoalIconUrl': savingGoalIconUrl,
      'aiChatId': aiChatId,
    };
  }
}

