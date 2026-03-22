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

  /// Tạo DateRangeDTO tùy chỉnh từ startDate + endDate do user chọn
  factory DateRangeDTO.custom({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startLabel = '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
    final endLabel = '${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}';
    return DateRangeDTO(
      label: '$startLabel - $endLabel',
      startDate: startDate,
      endDate: endDate,
      type: DateRangeType.custom,
    );
  }
}

