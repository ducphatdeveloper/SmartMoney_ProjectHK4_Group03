/// Response hiển thị thông tin sự kiện.
/// Tương ứng: EventResponse.java (server)
class EventResponse {
  final int id;
  final String eventName;
  final String? eventIconUrl;
  final DateTime? beginDate;
  final DateTime endDate;
  final bool? finished;
  final String? currencyCode;
  final double totalIncome;
  final double totalExpense;
  final double netAmount;

  const EventResponse({
    required this.id,
    required this.eventName,
    this.eventIconUrl,
    this.beginDate,
    required this.endDate,
    this.finished,
    this.currencyCode,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.netAmount = 0,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) {
    return EventResponse(
      id: json['id'] as int,
      eventName: json['eventName'] as String,
      eventIconUrl: json['eventIconUrl'] as String?,
      beginDate: json['beginDate'] != null
          ? DateTime.parse(json['beginDate'] as String)
          : null,
      endDate: DateTime.parse(json['endDate'] as String),
      finished: json['finished'] as bool?,
      currencyCode: json['currencyCode'] as String?,
      totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

