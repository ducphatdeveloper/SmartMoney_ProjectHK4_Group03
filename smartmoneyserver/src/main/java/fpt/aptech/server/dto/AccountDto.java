package fpt.aptech.server.dto;

import fpt.aptech.server.entity.Account;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AccountDto {
    private Integer id;
    private String accEmail;
    private String accPhone;
    private boolean locked;

    // Constructor giúp chuyển đổi từ Account entity sang AccountDto một cách dễ dàng
    public AccountDto(Account account) {
        this.id = account.getId();
        this.accEmail = account.getAccEmail();
        this.accPhone = account.getAccPhone();
        this.locked = account.getLocked();
    }
}