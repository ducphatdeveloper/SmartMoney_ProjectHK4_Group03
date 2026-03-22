/// Request gửi tin nhắn chat AI.
/// Tương ứng: AiChatRequest.java (server)
class AiChatRequest {
  final String message;
  final int? attachmentType;

  const AiChatRequest({
    required this.message,
    this.attachmentType,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'attachmentType': attachmentType,
      };
}

