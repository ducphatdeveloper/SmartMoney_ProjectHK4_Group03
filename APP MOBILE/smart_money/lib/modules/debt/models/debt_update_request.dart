/// Request cập nhật khoản nợ (chỉ sửa tên, ngày hẹn, ghi chú).
/// Tương ứng: DebtUpdateRequest.java (server)
class DebtUpdateRequest {
  final String personName;
  final DateTime? dueDate;
  final String? note;

  const DebtUpdateRequest({
    required this.personName,
    this.dueDate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'personName': personName,
    };
    if (dueDate != null) map['dueDate'] = dueDate!.toIso8601String();
    if (note != null) map['note'] = note;
    return map;
  }
}

