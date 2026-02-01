package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Collections;

@Entity
@Table(name = "tAccounts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Account implements UserDetails {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Vai trò của tài khoản, EAGER fetch để tải ngay cho Spring Security.
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "role_id", nullable = false)
    private Role role;

    // Tiền tệ mặc định của tài khoản.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "currency", referencedColumnName = "currency_code", nullable = false)
    private Currency currency;

    // SĐT có thể null nếu đăng ký bằng email.
    @Column(name = "acc_phone", length = 20)
    private String accPhone;

    // Email có thể null nếu đăng ký bằng SĐT.
    @Column(name = "acc_email", length = 100)
    private String accEmail;

    // Mật khẩu đã được hash.
    @Column(name = "hash_password", nullable = false, length = 255)
    private String hashPassword;

    @Column(name = "avatar_url", length = 2048)
    private String avatarUrl;

    // Trạng thái khóa tài khoản. true = bị khóa.
    @Column(name = "locked", nullable = false)
    private Boolean locked = false;

    // Tự động gán ngày giờ tạo, không thể cập nhật.
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    // Tự động cập nhật ngày giờ khi có thay đổi.
    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role.getRoleName()));
    }

    @Override
    public String getPassword() {
        return hashPassword;
    }

    @Override
    public String getUsername() {
        return accEmail;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return !locked;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}