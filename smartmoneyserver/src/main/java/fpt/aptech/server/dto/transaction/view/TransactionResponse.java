package fpt.aptech.server.dto.transaction.view;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO để hiển thị thông tin một giao dịch.
 * Record này định nghĩa cấu trúc dữ liệu "giàu thông tin" mà server gửi về cho client.
 */
@Builder
public record TransactionResponse(
    Long id,
    BigDecimal amount,
    String note,
    LocalDateTime transDate, // Đổi tên cho khớp với Entity
    String withPerson,
    boolean reportable,
    Integer sourceType, // 1: manual | 2: chat | 3: voice | 4: receipt | 5: planned

    // --- Dữ liệu được join từ các bảng liên quan ---

    Integer walletId,    // ID Ví (Flutter cần để pre-fill form sửa)
    String walletName,
    String walletIconUrl, // Icon của Ví

    Integer categoryId,  // ID Danh mục (Flutter cần để pre-fill form sửa)
    String categoryName,
    String categoryIconUrl, // Icon của Danh mục
    boolean categoryType, // true: Thu, false: Chi

    Integer eventId,     // ID Sự kiện (Flutter cần để pre-fill form sửa)
    String eventName,

    Integer debtId, // ID của khoản nợ liên quan (nếu có)

    Integer savingGoalId, // ID Mục tiêu tiết kiệm (Flutter cần để pre-fill form sửa)
    String savingGoalName,
    String savingGoalIconUrl // Icon của Mục tiêu tiết kiệm (nếu dùng thay ví)
) {}
