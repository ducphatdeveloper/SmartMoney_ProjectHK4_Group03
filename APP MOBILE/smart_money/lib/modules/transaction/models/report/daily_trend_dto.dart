// modules/transaction/models/report/daily_trend_dto.dart
// Map đúng với DailyTrendDTO.java của Spring Boot
// Dùng cho biểu đồ cột/đường theo ngày (REPORT)

class DailyTrendDTO {
  final DateTime date;
  final double totalIncome;
  final double totalExpense;

  const DailyTrendDTO({
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
  });

  factory DailyTrendDTO.fromJson(Map<String, dynamic> json) {
    return DailyTrendDTO(
      date: DateTime.parse(json['date'] as String),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
    );
  }
}

