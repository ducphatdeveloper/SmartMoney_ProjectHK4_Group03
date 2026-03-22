/// Một tin nhắn trong lịch sử chat AI.
/// Tương ứng: ChatHistoryItem.java (server)
class ChatHistoryItem {
  final int id;
  final String messageContent;
  final bool senderType;
  final int? intent;
  final String? attachmentUrl;
  final int? attachmentType;
  final DateTime createdAt;

  const ChatHistoryItem({
    required this.id,
    required this.messageContent,
    required this.senderType,
    this.intent,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
  });

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) {
    return ChatHistoryItem(
      id: json['id'] as int,
      messageContent: json['messageContent'] as String,
      senderType: json['senderType'] as bool,
      intent: json['intent'] as int?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentType: json['attachmentType'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

