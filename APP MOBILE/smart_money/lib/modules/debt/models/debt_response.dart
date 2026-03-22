/// Response hiển thị thông tin khoản nợ.
/// Tương ứng: DebtResponse.java (server)
/// Nợ được TẠO tự động khi tạo giao dịch có category Cho vay/Đi vay.
class DebtResponse {
  final int id;
  final String personName;
  final bool debtType;
  final double totalAmount;
  final double remainAmount;
  final double paidAmount;
  final bool? finished;
  final DateTime? dueDate;
  final String? note;
  final DateTime? createdAt;

  const DebtResponse({
    required this.id,
    required this.personName,
    required this.debtType,
    required this.totalAmount,
    required this.remainAmount,
    required this.paidAmount,
    this.finished,
    this.dueDate,
    this.note,
    this.createdAt,
  });

  factory DebtResponse.fromJson(Map<String, dynamic> json) {
    return DebtResponse(
      id: json['id'] as int,
      personName: json['personName'] as String,
      debtType: json['debtType'] as bool,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainAmount: (json['remainAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num).toDouble(),
      finished: json['finished'] as bool?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

