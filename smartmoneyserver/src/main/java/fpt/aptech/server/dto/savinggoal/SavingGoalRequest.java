package fpt.aptech.server.dto.savinggoal;

import jakarta.validation.constraints.DecimalMax;
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
    @NotBlank(message = "Goal name cannot be empty")
    private String goalName;

    // Số tiền mục tiêu > 0 (theo CHECK constraint)
    @NotNull(message = "Target amount cannot be empty")
    @DecimalMin(value = "0.01", message = "Target amount must be greater than 0")
    @DecimalMax(value = "1000000000000.00", message = "Target amount must not exceed 1,000 billion VND")
    private BigDecimal targetAmount;

    // Số tiền khởi tạo (nếu có)
    @PositiveOrZero(message = "Initial amount must be greater than or equal to 0")
    @DecimalMax(value = "1000000000000.00", message = "Initial amount must not exceed 1,000 billion VND")
    private BigDecimal initialAmount;

    // Currency FK
    @NotBlank(message = "Currency code cannot be empty")
    @Pattern(regexp = "VND", message = "Saving goal currently only supports VND.")
    private String currencyCode;

    // Phải là ngày tương lai
    @NotNull(message = "End date cannot be empty")
    @FutureOrPresent(message = "End date must be today or in the future")
    private LocalDate endDate;

    private String goalImageUrl;

    private Boolean notified;
    private Boolean reportable;

    // Dùng khi deposit (update) - Có thể bỏ nếu tách API deposit riêng
    private BigDecimal amount;
}
