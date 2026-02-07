package fpt.aptech.server.dto.savinggoals.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CreateSavingGoalRequest {

    @NotNull
    private Integer accId;

    @NotBlank
    private String currencyCode; // VND

    @NotBlank
    private String goalName;

    @NotNull
    private Integer categoryId;

    @NotNull
    @Positive
    private BigDecimal targetAmount;

    @NotNull
    private LocalDate endDate;

    private String goalImageUrl; // icon / category
}
