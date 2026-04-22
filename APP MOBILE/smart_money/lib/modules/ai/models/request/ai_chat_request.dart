// modules/ai/models/request/ai_chat_request.dart
// DTO nhận yêu cầu chat từ Flutter gửi lên backend
// Map đúng với AiChatRequest.java của Spring Boot

class AiChatRequest {
  final String message; // Nội dung tin nhắn của người dùng
  final int? attachmentType; // null = text | 1 = image | 2 = voice

  const AiChatRequest({
    required this.message,
    this.attachmentType,
  });

  /// Chuyển sang JSON để gửi lên server
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (attachmentType != null) 'attachmentType': attachmentType,
    };
  }
}
