package fpt.aptech.server.dto.wallet;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class TransferRequest {
    @NotNull(message = "Source wallet ID is required")
    private Integer fromWalletId;

    @NotNull(message = "Destination wallet ID is required")
    private Integer toWalletId;

    @NotNull(message = "Transfer amount is required")
    @Positive(message = "Transfer amount must be greater than 0")
    private BigDecimal amount;

    private String note;
}
