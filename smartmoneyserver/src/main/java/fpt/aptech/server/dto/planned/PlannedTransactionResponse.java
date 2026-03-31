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
    String  walletIcon,      // ✅ THÊM: Icon URL ví (Flutter hiển thị icon ví)

    // Danh mục
    Integer categoryId,
    String  categoryName,
    String  categoryIcon,
    Boolean categoryType, // false=Chi, true=Thu

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
    String repeatDescription,

    // ══════════════════════════════════════════════════════════════════
    // ✅ BACKEND TÍNH SẴN — Cung cấp trạng thái & label rõ ràng cho UI
    // ══════════════════════════════════════════════════════════════════

    // Trạng thái hiển thị chính, quyết định màu sắc & hành động trên UI.
    // VD: "ACTIVE", "OVERDUE", "INACTIVE", "EXPIRED", "PAID"
    String displayStatus,

    // Label phụ, cung cấp thông tin chi tiết hơn cho người dùng.
    // VD: "Còn 3 lần", "Hết hạn 31/03/2026", "Đến hạn sau 5 ngày", "Quá hạn 2 ngày"
    String statusLabel,

    // Số lần lặp lại còn lại (chỉ có giá trị khi lặp theo số lần).
    // VD: 5, 4, 3, 2, 1
    Integer remainingCount,

    // Label ngày đến hạn đã format sẵn tiếng Việt.
    // VD: "Thứ Ba, 14 tháng 4 2026"
    String nextDueDateLabel
) {}
