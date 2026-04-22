// modules/ai/models/request/ai_execute_request.dart
// DTO nhận yêu cầu thực thi hành động từ Flutter gửi lên backend
// Map đúng với AiExecuteRequest.java của Spring Boot

class AiExecuteRequest {
  final String actionType; // Loại hành động (VD: create_transaction)
  final Map<String, dynamic> params; // Dữ liệu truyền vào cho hành động

  const AiExecuteRequest({
    required this.actionType,
    required this.params,
  });

  /// Chuyển sang JSON để gửi lên server
  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'params': params,
    };
  }
}
