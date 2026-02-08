package fpt.aptech.server.dto.transaction;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO cho việc tạo hoặc cập nhật một giao dịch.
 * Record này định nghĩa cấu trúc dữ liệu mà client phải gửi lên.
 */
public record TransactionRequest(
    @NotNull(message = "ID của ví không được để trống.")
    Integer walletId,

    @NotNull(message = "Số tiền không được để trống.")
    @Positive(message = "Số tiền phải là số dương.")
    BigDecimal amount,

    @NotNull(message = "ID của danh mục không được để trống.")
    Integer categoryId,

    String note, // Ghi chú (có thể null)

    @NotNull(message = "Ngày giao dịch không được để trống.")
    LocalDateTime transDate, // Đổi tên cho khớp với Entity

    String withPerson, // Giao dịch với ai (có thể null)

    Integer eventId, // ID sự kiện (có thể null nếu không thuộc sự kiện nào)

    @NotNull(message = "Trạng thái báo cáo không được để trống.")
    Boolean reportable
) {}
