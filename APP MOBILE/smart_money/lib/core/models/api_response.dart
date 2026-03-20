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
    return ApiResponse<T>(
      success:   json['success'] ?? false,
      message:   json['message'] ?? '',
      // timestamp có thể là String hoặc List<int> tùy Jackson config
      // → Lưu dạng String để an toàn
      timestamp: json['timestamp']?.toString(),
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}