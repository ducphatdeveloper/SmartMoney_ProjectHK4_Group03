package fpt.aptech.server.dto.debt;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.time.LocalDateTime;

/**
 * DTO cho việc cập nhật một khoản nợ.
 * Chỉ cho phép sửa: tên người, ngày hẹn, ghi chú.
 * KHÔNG cho phép sửa: totalAmount, debtType (vì ảnh hưởng đến logic tài chính).
 */
@Builder
public record DebtUpdateRequest(

        @NotBlank(message = "Person name cannot be empty.")
        @Size(max = 200, message = "Person name must not exceed 200 characters.")
        String personName,

        // [VALIDATE] Bắt buộc nhập ngày hẹn trả — validate quá khứ được xử lý trong DebtServiceImpl
        @NotNull(message = "Please select a due date for the debt.")
        LocalDateTime dueDate,

        @Size(max = 500, message = "Note must not exceed 500 characters.")
        String note // Ghi chú (có thể null)
) {}
