package fpt.aptech.server.dto.transaction.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO cho việc tạo hoặc cập nhật một giao dịch.
 * Record này định nghĩa cấu trúc dữ liệu mà client phải gửi lên.
 */
@Builder
public record TransactionRequest(
    // Bỏ @NotNull vì có thể chọn goalId thay thế
    Integer walletId,

    // Thêm goalId cho ví tiết kiệm
    Integer goalId,

    @NotNull(message = "Amount cannot be empty.")
    @Positive(message = "Amount must be positive.")
    BigDecimal amount,

    @NotNull(message = "Category ID cannot be empty.")
    Integer categoryId,

    String note, // Ghi chú (có thể null)

    @NotNull(message = "Transaction date cannot be empty.")
    LocalDateTime transDate, // Đổi tên cho khớp với Entity

    String withPerson, // Giao dịch với ai (có thể null)

    Integer eventId, // ID sự kiện (có thể null nếu không thuộc sự kiện nào)

    // Thêm reminderDate cho nhắc nhở
    LocalDateTime reminderDate,

    @NotNull(message = "Report status cannot be empty.")
    Boolean reportable,

    // Các trường mới cho module Sổ nợ
    String personName,   // nullable — chỉ dùng khi category = Cho vay / Đi vay
    Integer debtId,      // nullable — chỉ dùng khi category = Trả nợ / Thu nợ
    LocalDateTime dueDate, // nullable - chỉ dùng khi tạo khoản nợ mới từ giao dịch

    //AI MODULE
    Integer sourceType,  // 1=manual|2=chat|3=voice|4=receipt|5=planned
    Integer aiChatId     // NULL nếu manual, NOT NULL nếu sourceType 2/3/4
) {}
