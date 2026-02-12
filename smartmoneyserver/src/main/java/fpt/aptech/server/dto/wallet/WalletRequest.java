package fpt.aptech.server.dto.wallet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class WalletRequest{
    @NotBlank(message = "Currency code is required")
    private String currencyCode;

    @NotBlank(message = "Wallet name is required")
    @Size(max = 100, message = "Wallet name must be less than 100 characters")
    private String walletName;

    @PositiveOrZero(message = "Balance must be >= 0")
    private BigDecimal balance;

    private Boolean notified;

    private Boolean reportable;

    @Size(max = 2048, message = "Image URL too long")
    private String goalImageUrl;
}
