package fpt.aptech.server.dto;

import fpt.aptech.server.entity.Account;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AccountDto {
    private Integer id;
    private String accEmail;
    private String accPhone;
    private boolean locked;
    private String avatarUrl;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private String roleName;
    private String currencyCode;
    
    // Thêm trạng thái online
    private boolean isOnline;
    private LocalDateTime lastActive;

    // Constructor giúp chuyển đổi từ Account entity sang AccountDto một cách dễ dàng
    public AccountDto(Account account) {
        this.id = account.getId();
        this.accEmail = account.getAccEmail();
        this.accPhone = account.getAccPhone();
        this.locked = account.getLocked();
        this.avatarUrl = account.getAvatarUrl();
        this.createdAt = account.getCreatedAt();
        this.updatedAt = account.getUpdatedAt();
        
        if (account.getRole() != null) {
            this.roleName = account.getRole().getRoleName();
        }
        
        if (account.getCurrency() != null) {
            this.currencyCode = account.getCurrency().getCurrencyCode();
        }
    }
}