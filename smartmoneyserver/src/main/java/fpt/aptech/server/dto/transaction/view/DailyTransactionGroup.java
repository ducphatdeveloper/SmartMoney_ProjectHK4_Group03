package fpt.aptech.server.dto.transaction.view;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * DTO cho giao diện gom nhóm giao dịch theo ngày (Nhật ký).
 */
@Builder
public record DailyTransactionGroup(
    // Ngày của nhóm giao dịch
    LocalDate date,

    // Nhãn hiển thị đã được định dạng (VD: "Hôm nay", "Hôm qua", "Thứ Sáu, 14/03")
    String displayDateLabel,

    // Tổng thu/chi ròng của ngày hôm đó
    BigDecimal netAmount,

    // Danh sách chi tiết các giao dịch trong ngày
    List<TransactionResponse> transactions
) {}
