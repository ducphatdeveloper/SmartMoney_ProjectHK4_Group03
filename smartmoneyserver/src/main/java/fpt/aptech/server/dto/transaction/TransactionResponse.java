package fpt.aptech.server.dto.transaction;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO để hiển thị thông tin một giao dịch.
 * Record này định nghĩa cấu trúc dữ liệu "giàu thông tin" mà server gửi về cho client.
 */
public record TransactionResponse(
    Long id,
    BigDecimal amount,
    String note,
    LocalDateTime transDate, // Đổi tên cho khớp với Entity
    String withPerson,
    boolean reportable,
    
    // --- Dữ liệu được join từ các bảng liên quan ---
    
    String walletName,
    String categoryName,
    String categoryIconUrl,
    boolean categoryType, // true: Thu, false: Chi
    String eventName
) {}
