package fpt.aptech.server.dto.planned;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Builder
public record PlannedTransactionResponse(
    Integer id,

    // Ví
    Integer walletId,
    String  walletName,

    // Danh mục
    Integer categoryId,
    String  categoryName,
    String  categoryIcon,
    Boolean categoryType, // Đổi sang Boolean cho nhất quán

    // Nợ (nullable)
    Integer debtId,
    String  debtPersonName,

    String     note,
    BigDecimal amount,

    // 1: Bill | 2: Recurring
    Integer planType,

    // Lịch lặp
    Integer repeatType,      // 0-4
    Integer repeatInterval,
    Integer repeatOnDayVal,  // bitmask tuần

    LocalDate beginDate,
    LocalDate nextDueDate,   // Flutter dùng để hiển thị "Lần tiếp theo: Thứ Hai 16/03/2026"
    LocalDate lastExecutedAt,
    LocalDate endDate,

    Boolean  active,
    LocalDateTime createdAt,

    // Mô tả lịch lặp cho Flutter hiển thị (Backend tính sẵn)
    // VD: "Lặp vào ngày 14, mỗi 2 tháng" | "Lặp mỗi T2, T4, T6 hàng tuần"
    String repeatDescription
) {}
