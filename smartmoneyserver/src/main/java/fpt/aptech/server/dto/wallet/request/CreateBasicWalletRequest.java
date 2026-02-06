package fpt.aptech.server.dto.wallet.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class CreateBasicWalletRequest {
    private Integer accId;
    private String currencyCode;
    private String walletName;
    private BigDecimal balance;
    private Boolean notified;
    private Boolean reportable;
    private String goalImageUrl;
}
