/// Response hiển thị thông báo.
/// Tương ứng: dto/notification/NotificationResponse.java (server)
class NotificationResponse {
  final int id;
  final int? notifyType;
  final int? relatedId;
  final String? title;
  final String? content;
  final DateTime? scheduledTime;
  final bool? notifySent;
  final bool? notifyRead;
  final DateTime? createdAt;

  const NotificationResponse({
    required this.id,
    this.notifyType,
    this.relatedId,
    this.title,
    this.content,
    this.scheduledTime,
    this.notifySent,
    this.notifyRead,
    this.createdAt,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      id: json['id'] as int,
      notifyType: json['notifyType'] as int?,
      relatedId: json['relatedId'] != null
          ? (json['relatedId'] as num).toInt()
          : null,
      title: json['title'] as String?,
      content: json['content'] as String?,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : null,
      notifySent: json['notifySent'] as bool?,
      notifyRead: json['notifyRead'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// Tạo một bản sao của đối tượng hiện tại với các giá trị được cập nhật.
  /// Giải quyết lỗi 'notifyRead' can't be used as a setter.
  NotificationResponse copyWith({
    int? id,
    int? notifyType,
    int? relatedId,
    String? title,
    String? content,
    DateTime? scheduledTime,
    bool? notifySent,
    bool? notifyRead,
    DateTime? createdAt,
  }) {
    return NotificationResponse(
      id: id ?? this.id,
      notifyType: notifyType ?? this.notifyType,
      relatedId: relatedId ?? this.relatedId,
      title: title ?? this.title,
      content: content ?? this.content,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      notifySent: notifySent ?? this.notifySent,
      notifyRead: notifyRead ?? this.notifyRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
