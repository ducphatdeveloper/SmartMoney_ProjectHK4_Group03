// modules/transaction/models/report/category_report_dto.dart
// Map đúng với CategoryReportDTO.java của Spring Boot
// Báo cáo tổng hợp theo từng danh mục — dùng cho biểu đồ tròn (REPORT)

class CategoryReportDTO {
  final String categoryName;
  final double totalAmount;
  final bool? categoryType;   // true: Thu, false: Chi
  final String? categoryIcon;
  final double dailyAverage;  // Trung bình chi tiêu hàng ngày
  final double percentage;    // Tỷ trọng % so với tổng thu/chi

  const CategoryReportDTO({
    required this.categoryName,
    required this.totalAmount,
    this.categoryType,
    this.categoryIcon,
    required this.dailyAverage,
    required this.percentage,
  });

  factory CategoryReportDTO.fromJson(Map<String, dynamic> json) {
    return CategoryReportDTO(
      categoryName: json['categoryName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      categoryType: json['categoryType'] as bool?,
      categoryIcon: json['categoryIcon'] as String?,
      dailyAverage: (json['dailyAverage'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

