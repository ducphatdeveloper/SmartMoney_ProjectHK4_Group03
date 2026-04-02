// ===========================================================
// DebtResponse — DTO nhận từ server cho khoản nợ
// ===========================================================
// Trách nhiệm:
//   • Map 1-1 với DebtResponse.java ở backend
//   • Không chứa logic, chỉ chứa data + fromJson
//
// Gọi từ:
//   • DebtService → parse JSON từ API
//   • DebtProvider → lưu vào state
//   • DebtListScreen / DebtDetailScreen → hiển thị UI
//
// Trường đặc biệt:
//   • debtType: false = Cần Trả (Đi vay), true = Cần Thu (Cho vay)
//   • paidAmount = totalAmount - remainAmount (server tính sẵn)
//   • finished: false = đang nợ, true = đã hoàn thành
// ===========================================================

class DebtResponse {
  final int id;
  final String personName;         // Tên người vay/cho vay
  final bool debtType;             // false=Cần Trả, true=Cần Thu
  final double totalAmount;        // Tổng số tiền ban đầu
  final double remainAmount;       // Số tiền còn lại
  final double paidAmount;         // Đã trả/thu (server tính = total - remain)
  final bool finished;             // false=đang nợ, true=đã hoàn thành
  final DateTime? dueDate;         // Ngày hẹn trả (có thể null)
  final String? note;              // Ghi chú (có thể null)
  final DateTime createdAt;        // Ngày tạo khoản nợ

  const DebtResponse({
    required this.id,
    required this.personName,
    required this.debtType,
    required this.totalAmount,
    required this.remainAmount,
    required this.paidAmount,
    required this.finished,
    this.dueDate,
    this.note,
    required this.createdAt,
  });

  factory DebtResponse.fromJson(Map<String, dynamic> json) {
    return DebtResponse(
      id:            json['id']          as int,
      personName:    json['personName']  as String,
      debtType:      json['debtType']    as bool,
      totalAmount:   (json['totalAmount']  as num).toDouble(),
      remainAmount:  (json['remainAmount'] as num).toDouble(),
      paidAmount:    (json['paidAmount']   as num).toDouble(),
      finished:      json['finished']    as bool,
      // dueDate: null nếu user chưa đặt hạn trả
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      note:          json['note']        as String?,
      createdAt:     DateTime.parse(json['createdAt'] as String),
    );
  }

  // --------------- Helper tính % tiến độ trả nợ ---------------

  /// Tỷ lệ đã trả/thu — dùng cho LinearProgressIndicator
  /// Trả về 0.0 → 1.0 (đã trả bao nhiêu % trong tổng số)
  double get progress =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

  /// Label loại nợ cho UI (phân biệt 2 tab)
  String get debtTypeLabel => debtType ? 'Cần Thu' : 'Cần Trả';

  /// Label trạng thái cho UI (header section)
  String get finishedLabel => finished
      ? (debtType ? 'Đã nhận hết' : 'Đã trả hết')
      : (debtType ? 'Chưa thu'   : 'Chưa trả');
}
