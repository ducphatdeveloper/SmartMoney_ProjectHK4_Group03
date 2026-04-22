// modules/ai/models/response/receipt_response.dart
// DTO thông tin hóa đơn OCR để hiển thị trong Flutter
// Map đúng với Receipt entity của Spring Boot

class ReceiptResponse {
  final int id; // ID hóa đơn (cũng là ID của conversation)
  final String imageUrl; // URL ảnh hóa đơn
  final String? rawOcrText; // Text gốc từ OCR
  final Map<String, dynamic> processedData; // Dữ liệu đã parse (JSON format)
  final String receiptStatus; // Trạng thái: pending | processed | error
  final DateTime createdAt; // Thời gian tạo

  const ReceiptResponse({
    required this.id,
    required this.imageUrl,
    this.rawOcrText,
    required this.processedData,
    required this.receiptStatus,
    required this.createdAt,
  });

  /// Parse từ JSON server trả về
  factory ReceiptResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptResponse(
      id: json['id'] as int,
      imageUrl: json['imageUrl'] as String,
      rawOcrText: json['rawOcrText'] as String?,
      processedData: (json['processedData'] as Map<String, dynamic>?) ?? {},
      receiptStatus: json['receiptStatus'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Chuyển sang JSON (dùng khi cần cache local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      if (rawOcrText != null) 'rawOcrText': rawOcrText,
      'processedData': processedData,
      'receiptStatus': receiptStatus,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Kiểm tra xem hóa đơn đã được xử lý xong chưa
  bool get isProcessed => receiptStatus == 'processed';

  /// Kiểm tra xem hóa đơn đang chờ xử lý
  bool get isPending => receiptStatus == 'pending';

  /// Kiểm tra xem hóa đơn có lỗi không
  bool get isError => receiptStatus == 'error';
}
