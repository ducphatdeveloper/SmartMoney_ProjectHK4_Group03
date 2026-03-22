/// Response phản hồi từ AI Chat.
/// Tương ứng: AiChatResponse.java (server)
class AiChatResponse {
  final int? conversationId;
  final String reply;
  final int? intent;
  final AiAction? action;

  const AiChatResponse({
    this.conversationId,
    required this.reply,
    this.intent,
    this.action,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      conversationId: json['conversationId'] as int?,
      reply: json['reply'] as String,
      intent: json['intent'] as int?,
      action: json['action'] != null
          ? AiAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Hành động AI gợi ý hoặc đã thực thi.
/// Tương ứng: AiChatResponse.AiAction (inner record)
class AiAction {
  final String type;
  final bool? executed;
  final Map<String, dynamic>? params;
  final List<String>? suggestions;

  const AiAction({
    required this.type,
    this.executed,
    this.params,
    this.suggestions,
  });

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: json['type'] as String,
      executed: json['executed'] as bool?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'] as List)
          : null,
    );
  }
}

