package fpt.aptech.server.dto.wallet.reponse;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;

@Getter
@Builder
public class TotalWalletItemResponse {
    private String walletName;
    private BigDecimal balance;
    private String currencyCode;
}
