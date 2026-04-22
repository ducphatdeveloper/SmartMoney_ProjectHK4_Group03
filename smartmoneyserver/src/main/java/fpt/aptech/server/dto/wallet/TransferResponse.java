package fpt.aptech.server.dto.wallet;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;

@Getter
@Builder
public class TransferResponse {
    private String message;
    private BigDecimal transferredAmount;
    private BigDecimal fromWalletBalance;
    private BigDecimal toWalletBalance;
}
