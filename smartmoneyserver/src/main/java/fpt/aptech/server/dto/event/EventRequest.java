package fpt.aptech.server.dto.event;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.time.LocalDate;

@Builder
public record EventRequest(
    @NotBlank(message = "Tên sự kiện không được để trống")
    @Size(max = 200, message = "Tên sự kiện tối đa 200 ký tự")
    String eventName,

    @Size(max = 2048, message = "URL icon quá dài")
    String eventIconUrl,

    @NotNull(message = "Ngày bắt đầu không được để trống")
    LocalDate beginDate,

    @NotNull(message = "Ngày kết thúc không được để trống")
    @FutureOrPresent(message = "Ngày kết thúc phải là ngày hiện tại hoặc trong tương lai")
    LocalDate endDate,

    @NotNull(message = "Mã tiền tệ không được để trống")
    String currencyCode
) {}