// modules/ai/models/response/chat_history_item.dart
// DTO lịch sử trò chuyện để hiển thị trong Flutter
// Map đúng với ChatHistoryItem.java của Spring Boot

import '../../enums/ai_intent.dart';

class ChatHistoryItem {
  final int id; // ID trò chuyện trong hệ thống
  final String messageContent; // Nội dung tin nhắn
  final bool senderType; // false = Người dùng, true = AI
  final AiIntent? intent; // Ý định trò chuyện
  final String? attachmentUrl; // (Optional) Đường dẫn hình ảnh
  final int? attachmentType; // 1 = Image, 2 = Voice, Null = Text
  final DateTime createdAt; // Thời gian gửi tin

  const ChatHistoryItem({
    required this.id,
    required this.messageContent,
    required this.senderType,
    this.intent,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
  });

  /// Parse từ JSON server trả về
  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) {
    // Bước 1: Parse intent - có thể là string ("GENERAL_CHAT") hoặc integer (4)
    AiIntent? parsedIntent;
    if (json['intent'] != null) {
      if (json['intent'] is String) {
        // Backend trả về string: "GENERAL_CHAT", "ADD_TRANSACTION", ...
        parsedIntent = AiIntent.fromString(json['intent'] as String);
      } else if (json['intent'] is int) {
        // Backend trả về integer: 4, 1, 2, ...
        parsedIntent = AiIntent.fromValue(json['intent'] as int);
      }
    }

    return ChatHistoryItem(
      id: json['id'] as int,
      messageContent: json['messageContent'] as String? ?? '',
      senderType: json['senderType'] as bool? ?? false,
      intent: parsedIntent,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentType: json['attachmentType'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Chuyển sang JSON (dùng khi cần cache local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageContent': messageContent,
      'senderType': senderType,
      if (intent != null) 'intent': intent!.value,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentType != null) 'attachmentType': attachmentType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
