class TransactionModel {
  final String id;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String? note;
  final TransactionType type;

  TransactionModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note,
    this.type = TransactionType.expense,
  });

  /// 👇 Title hiển thị cho UI (Money Lover style)
  String get displayTitle {
    if (note != null && note!.trim().isNotEmpty) {
      return note!;
    }
    return categoryId;
  }
}

class TransactionType {
  static const TransactionType expense = TransactionType._("expense");
  static const TransactionType income = TransactionType._("income");

  final String value;

  const TransactionType._(this.value);
}
