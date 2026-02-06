package fpt.aptech.server.dto.wallet.reponse;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.util.List;

@Getter
@Builder
public class TotalWalletResponse {

    private Integer accId;
    private String walletName; // "Ví tổng"
    private BigDecimal totalBalance;
    private String currencyCode;

    private List<TotalWalletItemResponse> wallets;
}

