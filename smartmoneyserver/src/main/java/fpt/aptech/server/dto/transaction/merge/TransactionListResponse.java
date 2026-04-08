package fpt.aptech.server.dto.transaction.merge;

import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import lombok.Builder;
import java.math.BigDecimal;
import java.util.List;

@Builder
public record TransactionListResponse(
        BigDecimal totalIncome,           // Tổng thu
        BigDecimal totalExpense,          // Tổng chi
        BigDecimal netAmount,             // Số dư ròng (Thu - Chi)
        int transactionCount,             // Tổng số lượng giao dịch
        List<DailyTransactionGroup> dailyGroups // Danh sách nhóm theo ngày
) {
    public TransactionListResponse {
        if (totalIncome == null) totalIncome = BigDecimal.ZERO;
        if (totalExpense == null) totalExpense = BigDecimal.ZERO;
        if (netAmount == null) netAmount = BigDecimal.ZERO;
        if (dailyGroups == null) dailyGroups = List.of();
    }
}