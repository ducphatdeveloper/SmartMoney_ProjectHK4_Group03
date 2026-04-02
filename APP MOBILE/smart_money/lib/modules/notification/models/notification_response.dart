class NotificationResponse {
  final int id;
  final String title;
  final String content;
  final int notifyType;
  final bool notifyRead;
  final String? scheduledTime;

  NotificationResponse({
    required this.id,
    required this.title,
    required this.content,
    required this.notifyType,
    required this.notifyRead,
    this.scheduledTime,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      notifyType: json['notifyType'] ?? 0,
      notifyRead: json['notifyRead'] ?? false,
      scheduledTime: json['scheduledTime'],
    );
  }
}