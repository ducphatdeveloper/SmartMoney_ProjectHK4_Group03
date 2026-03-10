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
    
    // --- Dữ liệu được join từ các bảng liên quan ---
    
    String walletName,
    String walletIconUrl, // Icon của Ví

    String categoryName,
    String categoryIconUrl, // Icon của Danh mục
    boolean categoryType, // true: Thu, false: Chi

    String eventName,

    String savingGoalName,
    String savingGoalIconUrl // Icon của Mục tiêu tiết kiệm (nếu dùng thay ví)
) {}