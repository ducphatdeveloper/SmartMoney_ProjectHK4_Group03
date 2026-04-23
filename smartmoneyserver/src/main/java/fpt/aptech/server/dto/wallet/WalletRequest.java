package fpt.aptech.server.dto.wallet;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class WalletRequest{
    @NotBlank(message = "Currency code cannot be empty")
    @Pattern(regexp = "VND", message = "Wallet currently only supports VND.")
    private String currencyCode;

    @NotBlank(message = "Wallet name cannot be empty")
    @Size(max = 100, message = "Wallet name must not exceed 100 characters")
    private String walletName;

    @PositiveOrZero(message = "Balance must be greater than or equal to 0")
    @DecimalMax(value = "1000000000000.00", message = "Balance must not exceed 1,000 billion VND")
    private BigDecimal balance;

    private Boolean notified;

    private Boolean reportable;

    @Size(max = 2048, message = "Image URL is too long")
    private String goalImageUrl;
}