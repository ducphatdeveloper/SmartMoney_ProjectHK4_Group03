// modules/ai/enums/ai_intent.dart
// Enum định nghĩa mục đích của tin nhắn AI (Intent)
// Map đúng với AiIntent.java của Spring Boot

enum AiIntent {
  addTransaction(1, 'Thêm giao dịch mới'),
  viewReport(2, 'Xem báo cáo chi tiêu'),
  viewBudget(3, 'Xem ngân sách'),
  generalChat(4, 'Trò chuyện chung'),
  remindTask(5, 'Đặt nhắc nhở');

  final int value; // Giá trị lưu vào database
  final String displayName; // Tên hiển thị tiếng Việt

  const AiIntent(this.value, this.displayName);

  /// Lấy enum từ giá trị integer (từ database)
  /// Trả về generalChat nếu không tìm thấy
  static AiIntent fromValue(int? value) {
    // Bước 1: Kiểm tra giá trị null
    if (value == null) {
      return generalChat;
    }

    // Bước 2: Duyệt qua các enum để tìm giá trị tương ứng
    for (AiIntent intent in AiIntent.values) {
      if (intent.value == value) {
        return intent;
      }
    }

    // Bước 3: Trả về mặc định nếu không khớp
    return generalChat;
  }

  /// Lấy enum từ string (từ backend response)
  /// Trả về generalChat nếu không tìm thấy
  static AiIntent fromString(String? value) {
    // Bước 1: Kiểm tra giá trị null
    if (value == null) {
      return generalChat;
    }

    // Bước 2: Convert string sang enum name và so sánh
    final upperValue = value.toUpperCase();
    for (AiIntent intent in AiIntent.values) {
      if (intent.name.toUpperCase() == upperValue) {
        return intent;
      }
    }

    // Bước 3: Trả về mặc định nếu không khớp
    return generalChat;
  }
}
