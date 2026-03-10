package fpt.aptech.server.dto.transaction.report;

import lombok.Builder;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * DTO cho biểu đồ cột/đường theo ngày.
 * Mỗi object đại diện cho thu/chi của một ngày cụ thể.
 */
@Builder
public record DailyTrendDTO(
    LocalDate date,
    BigDecimal totalIncome,
    BigDecimal totalExpense
) {
    public DailyTrendDTO(java.util.Date sqlDate, BigDecimal totalIncome, BigDecimal totalExpense) {
        this(
            (sqlDate instanceof java.sql.Date) 
                ? ((java.sql.Date) sqlDate).toLocalDate() 
                : sqlDate.toInstant().atZone(java.time.ZoneId.systemDefault()).toLocalDate(),
            totalIncome,
            totalExpense
        );
    }
}