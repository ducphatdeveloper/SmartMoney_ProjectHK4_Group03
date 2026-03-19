package fpt.aptech.server.dto.event;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.time.LocalDate;

/**
 * DTO cho việc CẬP NHẬT một sự kiện đã có.
 * Không có @FutureOrPresent để cho phép sửa các sự kiện cũ.
 */
@Builder
public record EventUpdateRequest(
        @NotBlank(message = "Tên sự kiện không được để trống")
        @Size(max = 200, message = "Tên sự kiện không được quá 200 ký tự")
        String eventName,

        @Size(max = 2048, message = "URL icon không được quá 2048 ký tự")
        String eventIconUrl,

        @NotNull(message = "Ngày kết thúc không được để trống")
        LocalDate endDate,

        @NotBlank(message = "Mã tiền tệ không được để trống")
        @Pattern(regexp = "VND", message = "Sự kiện hiện chỉ hỗ trợ VND.")
        String currencyCode
) {}
