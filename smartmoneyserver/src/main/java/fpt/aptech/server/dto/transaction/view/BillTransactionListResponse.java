package fpt.aptech.server.dto.transaction.view;

import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import lombok.Builder;

import java.util.List;

// Trả về 2 phần cho màn hình xem giao dịch của Hóa đơn:
//   - summary: tổng thu/chi (Frontend tự tính "Còn lại" = totalIncome - totalExpense)
//   - groupedTransactions: danh sách giao dịch gom theo ngày
@Builder
public record BillTransactionListResponse(
    long totalCount,                          // Tổng số giao dịch
    TransactionTotalDTO summary,              // totalIncome + totalExpense
    List<DailyTransactionGroup> groupedTransactions  // Gom theo ngày
) {}

