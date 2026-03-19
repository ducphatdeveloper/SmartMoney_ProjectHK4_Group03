package fpt.aptech.server.dto.event;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.time.LocalDate;

/**
 * DTO cho việc TẠO một sự kiện mới.
 * Dùng record và @Builder cho code ngắn gọn, an toàn.
 */
@Builder
public record EventCreateRequest(
        @NotBlank(message = "Tên sự kiện không được để trống")
        @Size(max = 200, message = "Tên sự kiện không được quá 200 ký tự")
        String eventName,

        @Size(max = 2048, message = "URL icon không được quá 2048 ký tự")
        String eventIconUrl,

        @NotNull(message = "Ngày kết thúc không được để trống")
        @FutureOrPresent(message = "Ngày kết thúc phải là hôm nay hoặc trong tương lai")
        LocalDate endDate,

        @NotBlank(message = "Mã tiền tệ không được để trống")
        @Pattern(regexp = "VND", message = "Sự kiện hiện chỉ hỗ trợ VND.")
        String currencyCode
) {}
