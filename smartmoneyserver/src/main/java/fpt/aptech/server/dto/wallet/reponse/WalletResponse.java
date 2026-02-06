package fpt.aptech.server.dto.wallet.reponse;


import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;

@Getter
@Builder
public class WalletResponse {
    private Integer id;
    private String walletName;
    private BigDecimal balance;
    private String currencyCode;
    private Boolean notified;
    private Boolean reportable;
    private String goalImageUrl;
}
