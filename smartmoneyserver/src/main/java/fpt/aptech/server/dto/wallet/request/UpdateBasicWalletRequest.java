package fpt.aptech.server.dto.wallet.request;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateBasicWalletRequest {
    private String walletName;
    private Boolean notified;
    private Boolean reportable;
    private String goalImageUrl;
}
