import '../enums/date_range_type.dart';

/// Khoảng thời gian cho thanh trượt (tuần/tháng/quý/năm).
/// Tương ứng: DateRangeDTO.java (server)
class DateRangeDTO {
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final DateRangeType type;

  const DateRangeDTO({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  factory DateRangeDTO.fromJson(Map<String, dynamic> json) {
    return DateRangeDTO(
      label: json['label'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      type: DateRangeType.fromString(json['type'] as String),
    );
  }
}

