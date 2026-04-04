package fpt.aptech.server.dto;

import fpt.aptech.server.entity.Account;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.List;
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
    // Thông tin bổ sung
    private int onlineDevicesCount;
    private List<String> onlinePlatforms;

    // Thông tin cá nhân
    private String accUsername; // Tên hiển thị, có thể lấy từ fullname hoặc email
    @Size(max = 60, message = "Họ và tên không được vượt quá 60 ký tự")
    private String fullname;
    @Pattern(regexp = "Nam|Nữ|Khác|", message = "Giới tính không hợp lệ (chấp nhận Nam, Nữ, Khác hoặc để trống)")
    private String gender;
    @PastOrPresent(message = "Ngày sinh không được ở tương lai")
    private LocalDate dateofbirth;
    @Size(max = 20, message = "Số CCCD không được vượt quá 20 ký tự")
    private String identityCard;
    @Size(max = 255, message = "Địa chỉ không được vượt quá 255 ký tự")
    private String address;

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

        // Map thông tin cá nhân
        this.fullname = account.getFullname();
        this.gender = account.getGender();
        this.dateofbirth = account.getDateofbirth();
        this.identityCard = account.getIdentityCard();
        this.address = account.getAddress();

        // Gán accUsername (tên hiển thị)
        this.accUsername = (account.getFullname() != null && !account.getFullname().isEmpty()) ? account.getFullname() : account.getAccEmail();
    }
}