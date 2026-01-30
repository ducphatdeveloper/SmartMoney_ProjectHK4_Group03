package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Bảng quản lý các thiết bị đã đăng nhập của người dùng.
 * Dùng để quản lý session (refresh token) và gửi push notification (device token).
 */
@Entity
@Table(name = "tUserDevices")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Tài khoản sở hữu thiết bị này.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    // Token để gửi push notification (Firebase/APNs). Phải là duy nhất.
    @Column(name = "device_token", unique = true, nullable = false, length = 500)
    private String deviceToken;

    // JWT Refresh Token, dùng để làm mới Access Token.
    @Column(name = "refresh_token", length = 512)
    private String refreshToken;

    @Column(name = "refresh_token_expired_at")
    private LocalDateTime refreshTokenExpiredAt;

    // Loại thiết bị: "iOS", "Android", "Chrome_Windows"
    @Column(name = "device_type", nullable = false, length = 50)
    private String deviceType;

    // Tên gợi nhớ của thiết bị: "iPhone 15 Pro"
    @Column(name = "device_name", length = 100)
    private String deviceName;

    // Địa chỉ IP cuối cùng đăng nhập.
    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    // Trạng thái đăng nhập. false nếu người dùng đã chủ động logout.
    @Column(name = "logged_in", nullable = false)
    private Boolean loggedIn = true;

    // Thời gian hoạt động cuối cùng, dùng để xác định trạng thái "online".
    @Column(name = "last_active", nullable = false)
    private LocalDateTime lastActive = LocalDateTime.now();
}