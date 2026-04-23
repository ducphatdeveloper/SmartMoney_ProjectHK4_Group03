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
        @NotBlank(message = "Event name cannot be empty")
        @Size(max = 200, message = "Event name must not exceed 200 characters")
        String eventName,

        @Size(max = 2048, message = "Icon URL must not exceed 2048 characters")
        String eventIconUrl,

        @NotNull(message = "End date cannot be empty")
        LocalDate endDate,

        @NotBlank(message = "Currency code cannot be empty")
        @Pattern(regexp = "VND", message = "Event currently only supports VND.")
        String currencyCode
) {}
