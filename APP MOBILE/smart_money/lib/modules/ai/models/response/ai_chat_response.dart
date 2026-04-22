// modules/ai/models/response/ai_chat_response.dart
// DTO chứa thông tin phản hồi từ AI trả về cho Flutter
// Map đúng với AiChatResponse.java của Spring Boot

import 'ai_action.dart';

class AiChatResponse {
  final int? conversationId; // ID tin nhắn lưu dưới DB của AI (nullable vì backend không trả về trong response)
  final String reply; // Văn bản AI trả lời cho người dùng
  final int? intent; // Ý định của người dùng (1-5)
  final int? createdTransactionId; // (Optional) Nếu AI tạo thành công Giao dịch
  final int? receiptId; // (Optional) Nếu người dùng gửi kèm Hóa đơn để OCR
  final AiAction? action; // (Optional) Nếu AI cần chờ xác nhận thực thi

  const AiChatResponse({
    this.conversationId,
    required this.reply,
    this.intent,
    this.createdTransactionId,
    this.receiptId,
    this.action,
  });

  /// Parse từ JSON server trả về
  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      conversationId: json['conversationId'] as int?,
      reply: json['reply'] as String? ?? '',
      intent: json['intent'] as int?,
      createdTransactionId: json['createdTransactionId'] as int?,
      receiptId: json['receiptId'] as int?,
      action: json['action'] != null ? AiAction.fromJson(json['action'] as Map<String, dynamic>) : null,
    );
  }

  /// Chuyển sang JSON (dùng khi cần cache local)
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'reply': reply,
      if (intent != null) 'intent': intent,
      if (createdTransactionId != null) 'createdTransactionId': createdTransactionId,
      if (receiptId != null) 'receiptId': receiptId,
      if (action != null) 'action': action!.toJson(),
    };
  }
}
