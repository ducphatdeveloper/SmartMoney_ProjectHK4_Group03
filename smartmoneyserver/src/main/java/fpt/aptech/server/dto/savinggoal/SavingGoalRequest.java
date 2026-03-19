package fpt.aptech.server.dto.savinggoal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class SavingGoalRequest {
    // Tên mục tiêu
    @NotBlank(message = "Tên mục tiêu không được để trống")
    private String goalName;

    // Số tiền mục tiêu > 0 (theo CHECK constraint)
    @NotNull(message = "Số tiền mục tiêu không được để trống")
    @DecimalMin(value = "0.01", message = "Số tiền mục tiêu phải lớn hơn 0")
    private BigDecimal targetAmount;

    // Số tiền khởi tạo (nếu có)
    @PositiveOrZero(message = "Số tiền khởi tạo phải lớn hơn hoặc bằng 0")
    private BigDecimal initialAmount;

    // Currency FK
    @NotBlank(message = "Mã tiền tệ không được để trống")
    @Pattern(regexp = "VND", message = "Mục tiêu tiết kiệm hiện chỉ hỗ trợ VND.")
    private String currencyCode;

    // Phải là ngày tương lai
    @NotNull(message = "Ngày kết thúc không được để trống")
    @FutureOrPresent(message = "Ngày kết thúc phải là ngày hiện tại hoặc tương lai")
    private LocalDate endDate;

    private String goalImageUrl;

    private Boolean notified;
    private Boolean reportable;

    // Dùng khi deposit (update) - Có thể bỏ nếu tách API deposit riêng
    private BigDecimal amount;
}
