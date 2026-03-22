/// Request CẬP NHẬT sự kiện đã có.
/// Tương ứng: EventUpdateRequest.java (server)
class EventUpdateRequest {
  final String eventName;
  final String? eventIconUrl;
  final DateTime endDate;
  final String currencyCode;

  const EventUpdateRequest({
    required this.eventName,
    this.eventIconUrl,
    required this.endDate,
    this.currencyCode = 'VND',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'eventName': eventName,
      'endDate': _formatDate(endDate),
      'currencyCode': currencyCode,
    };
    if (eventIconUrl != null) map['eventIconUrl'] = eventIconUrl;
    return map;
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

