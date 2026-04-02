// ===========================================================
// DebtUpdateRequest — DTO gửi lên server khi sửa khoản nợ
// ===========================================================
// Trách nhiệm:
//   • Map 1-1 với DebtUpdateRequest.java ở backend
//   • Chỉ cho phép sửa 3 field: personName, dueDate, note
//   • KHÔNG bao gồm totalAmount, debtType (backend từ chối)
//
// Gọi từ:
//   • DebtEditScreen → build request rồi truyền vào DebtProvider
//   • DebtProvider.updateDebt() → gọi DebtService.update()
//
// API liên quan:
//   • PUT /api/debts/{id}
// ===========================================================

class DebtUpdateRequest {
  final String personName;   // Tên người vay/cho vay — bắt buộc, max 200 ký tự
  final DateTime? dueDate;   // Ngày hẹn trả — có thể null
  final String? note;        // Ghi chú — có thể null, max 500 ký tự

  const DebtUpdateRequest({
    required this.personName,
    this.dueDate,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'personName': personName,
      // Gửi null nếu user xóa ngày hẹn — backend chấp nhận null
      'dueDate': dueDate?.toIso8601String(),
      // Gửi null nếu user xóa ghi chú
      'note': note?.isEmpty == true ? null : note,
    };
  }
}
