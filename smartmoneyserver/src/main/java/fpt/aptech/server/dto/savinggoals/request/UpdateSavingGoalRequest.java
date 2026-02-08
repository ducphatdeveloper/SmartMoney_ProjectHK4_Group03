package fpt.aptech.server.dto.savinggoals.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class UpdateSavingGoalRequest {

    @NotNull
    private Integer accId;

    private String goalName;
    private Integer categoryId;
    private String currencyCode;

    private BigDecimal targetAmount;
    private LocalDate endDate;
    private String goalImageUrl;

    private Boolean notified;
    private Boolean reportable;

    // số tiền muốn nạp thêm vào ví tiết kiệm
    @Positive
    private BigDecimal amount;
}
