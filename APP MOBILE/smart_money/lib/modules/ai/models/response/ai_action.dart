// modules/ai/models/response/ai_action.dart
// DTO chứa dữ liệu hành động chờ xác nhận từ AI
// Map đúng với AiAction record trong AiChatResponse.java của Spring Boot

class AiAction {
  final String type; // Loại hành động (VD: create_transaction)
  final bool executed; // Trạng thái thực thi
  final Map<String, dynamic> params; // Thông tin chi tiết để gửi lại Server
  final List<String> suggestions; // Nút bấm gợi ý (VD: ["Có", "Không"])

  const AiAction({
    required this.type,
    required this.executed,
    required this.params,
    required this.suggestions,
  });

  /// Parse từ JSON server trả về
  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: json['type'] as String? ?? '',
      executed: json['executed'] as bool? ?? false,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      suggestions: (json['suggestions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// Chuyển sang JSON (dùng khi cần cache local)
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'executed': executed,
      'params': params,
      'suggestions': suggestions,
    };
  }
}
