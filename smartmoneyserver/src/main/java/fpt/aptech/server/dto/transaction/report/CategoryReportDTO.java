package fpt.aptech.server.dto.transaction.report;

import lombok.Builder;

import java.math.BigDecimal;

/**
 * DTO chứa dữ liệu báo cáo tổng hợp theo từng danh mục.
 * Thường dùng cho biểu đồ tròn.
 */
@Builder
public record CategoryReportDTO(
    String categoryName,
    BigDecimal totalAmount,
    Boolean categoryType, // true: Thu, false: Chi
    String categoryIcon,
    
    // Trung bình chi tiêu hàng ngày cho danh mục này
    BigDecimal dailyAverage,

    // Tỷ trọng % so với tổng thu/chi
    Double percentage
) {
    // Constructor phụ để tương thích với câu query JPQL trong TransactionRepository
    public CategoryReportDTO(String categoryName, BigDecimal totalAmount, Boolean categoryType, String categoryIcon) {
        this(categoryName, totalAmount, categoryType, categoryIcon, BigDecimal.ZERO, 0.0);
    }
}
