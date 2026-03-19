package fpt.aptech.server.dto.transaction.report;

import lombok.Builder;

import java.math.BigDecimal;

/**
 * DTO đơn giản để chứa kết quả tính tổng thu và tổng chi.
 * Dùng trong các câu query GROUP BY phức tạp.
 */
@Builder
public record TransactionTotalDTO(
        BigDecimal totalIncome,
        BigDecimal totalExpense
) {
    // Constructor phụ để xử lý trường hợp kết quả từ DB là null
    public TransactionTotalDTO {
        if (totalIncome == null) {
            totalIncome = BigDecimal.ZERO;
        }
        if (totalExpense == null) {
            totalExpense = BigDecimal.ZERO;
        }
    }
}
