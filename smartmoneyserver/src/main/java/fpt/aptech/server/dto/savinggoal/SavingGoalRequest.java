package fpt.aptech.server.dto.savinggoal;

import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class SavingGoalRequest {
    // Tên mục tiêu
    @NotBlank(message = "Goal name is required")
    private String goalName;

    // Số tiền mục tiêu > 0 (theo CHECK constraint)
    @NotNull
    @DecimalMin(value = "0.01", message = "Target amount must be > 0")
    private BigDecimal targetAmount;

    // Currency FK
    @NotBlank
    private String currencyCode;

    // Phải là ngày tương lai
    @NotNull
    @FutureOrPresent
    private LocalDate endDate;

    private String goalImageUrl;

    private Boolean notified;
    private Boolean reportable;

    // Dùng khi deposit (update)
    private BigDecimal amount;
}
