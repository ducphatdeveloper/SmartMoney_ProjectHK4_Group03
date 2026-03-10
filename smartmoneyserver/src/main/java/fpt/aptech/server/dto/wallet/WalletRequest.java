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
    @NotBlank(message = "Mã tiền tệ không được để trống")
    private String currencyCode;

    @NotBlank(message = "Tên ví không được để trống")
    @Size(max = 100, message = "Tên ví không được quá 100 ký tự")
    private String walletName;

    @PositiveOrZero(message = "Số dư phải lớn hơn hoặc bằng 0")
    private BigDecimal balance;

    private Boolean notified;

    private Boolean reportable;

    @Size(max = 2048, message = "URL hình ảnh quá dài")
    private String goalImageUrl;
}