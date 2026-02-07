package fpt.aptech.server.dto.savinggoals.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class DepositSavingRequest {

    @NotNull
    private Integer accId;

    @NotNull
    @Positive
    private BigDecimal amount;
}
