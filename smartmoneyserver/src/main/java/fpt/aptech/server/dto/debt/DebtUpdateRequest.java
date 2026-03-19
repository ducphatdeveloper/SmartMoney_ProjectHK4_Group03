package fpt.aptech.server.dto.debt;

import jakarta.validation.constraints.NotBlank;
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

        @NotBlank(message = "Tên người liên quan không được để trống.")
        @Size(max = 200, message = "Tên người liên quan không được quá 200 ký tự.")
        String personName,

        LocalDateTime dueDate, // Ngày hẹn trả (có thể null)

        @Size(max = 500, message = "Ghi chú không được quá 500 ký tự.")
        String note // Ghi chú (có thể null)
) {}
