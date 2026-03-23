// core/models/api_response.dart
// Map đúng với ApiResponse<T> của Spring Boot
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.timestamp,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic)? fromJsonT,
      ) {
    final isSuccess = json['success'] ?? false;

    // [FIX-BUG1] Khi success=false, KHÔNG gọi fromJsonT để parse data
    // Vì @Valid fail trả data là Map<field, message> → fromJsonT sẽ crash
    // khi cố parse Map lỗi thành DTO (VD: TransactionResponse.fromJson)
    // Giữ raw data để _extractErrorMessage() trong Provider đọc được
    T? parsedData;
    if (isSuccess && json['data'] != null && fromJsonT != null) {
      // Thành công → parse data bằng fromJsonT
      parsedData = fromJsonT(json['data']);
    } else if (!isSuccess && json['data'] != null) {
      // Thất bại → cố giữ raw data để _extractErrorMessage() đọc field errors
      // Nếu cast fail (VD: Map → TransactionResponse?) thì bỏ qua, dùng message thay thế
      try {
        parsedData = json['data'] as T?;
      } catch (_) {
        // Cast fail — không sao, _extractErrorMessage fallback sang response.message
        parsedData = null;
      }
    }

    return ApiResponse<T>(
      success:   isSuccess,
      message:   json['message'] ?? '',
      // timestamp có thể là String hoặc List<int> tùy Jackson config
      // → Lưu dạng String để an toàn
      timestamp: json['timestamp']?.toString(),
      data:      parsedData,
    );
  }
}