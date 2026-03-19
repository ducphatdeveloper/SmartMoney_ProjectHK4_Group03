package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.service.UserDevice.UserDeviceService;
import fpt.aptech.server.utils.JwtUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class AuthServiceImp implements AuthService {

    @Autowired private AccountRepository    accountRepository;
    @Autowired private UserDeviceRepository userDeviceRepository;
    @Autowired private RoleRepository       roleRepository;
    @Autowired private NotificationService  notificationService;
    @Autowired private UserDeviceService    userDeviceService;
    @Autowired private JwtUtils             jwtUtils;
    @Autowired private PasswordEncoder      passwordEncoder;
    @Autowired private UserDetailsService   userDetailsService;
    @Autowired private CurrencyRepository   currencyRepository;

    // =================================================================================
    // 1. XÁC THỰC (AUTHENTICATE)
    // =================================================================================

    /**
     * [1.1] Xác thực tập trung "tất cả trong một":
     * Bước 1 — Login (kiểm tra mật khẩu, trạng thái khóa).
     * Bước 2 — Tạo Access Token.
     * Bước 3 — Đăng ký thiết bị + tạo Refresh Token.
     * Bước 4 — Đóng gói toàn bộ thông tin vào AuthResponse.
     */
    @Override
    public AuthResponse authenticate(LoginRequest loginRequest, String ipAddress) {
        // Bước 1: Xác thực tài khoản
        Account account = login(loginRequest.getUsername(), loginRequest.getPassword());

        // Bước 2: Tạo Access Token
        String accessToken = generateAccessToken(account);

        // Bước 3: Đăng ký thiết bị + Refresh Token
        UserDevice device = userDeviceService.registerDevice(
                account,
                loginRequest.getDeviceToken(),
                loginRequest.getDeviceType(),
                loginRequest.getDeviceName() != null ? loginRequest.getDeviceName() : "Unknown Device",
                ipAddress
        );
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());
        device.setRefreshToken(refreshToken);
        userDeviceRepository.save(device);

        // Bước 4: Đóng gói AuthResponse
        UserInfoDTO userInfo = convertToUserInfoDTO(account);
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userInfo.getId())
                .accPhone(userInfo.getPhone())
                .accEmail(userInfo.getEmail())
                .avatarUrl(userInfo.getAvatarUrl())
                .currency(userInfo.getCurrencyCode())
                .roleId(userInfo.getRoleId())
                .roleCode(userInfo.getRoleCode())
                .roleName(userInfo.getRoleName())
                .permissions(userInfo.getPermissions())
                .loginAt(LocalDateTime.now())
                .build();
    }

    // =================================================================================
    // 2. ĐĂNG NHẬP & TOKEN
    // =================================================================================

    /**
     * [2.1] Kiểm tra username/password và trạng thái tài khoản.
     * Ném RuntimeException nếu không hợp lệ → GlobalExceptionHandler bắt lại.
     */
    @Override
    @Transactional(readOnly = true)
    public Account login(String username, String password) {
        // Bước 1: Tìm tài khoản theo email hoặc số điện thoại
        Account account = accountRepository.findByUsernameOrEmail(username)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại")); // Đổi RuntimeException

        // Bước 2: Kiểm tra tài khoản có bị khóa không
        if (account.getLocked()) {
            throw new IllegalStateException("Tài khoản hiện đang bị khóa"); // Đổi RuntimeException
        }

        // Bước 3: Kiểm tra mật khẩu
        if (!passwordEncoder.matches(password, account.getHashPassword())) {
            throw new IllegalArgumentException("Mật khẩu không chính xác"); // Đổi RuntimeException
        }

        return account;
    }


    @Override
    public String generateResetToken(String email) {
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại trong hệ thống"));

        // Tạo OTP 6 số ngẫu nhiên
        String otp = String.valueOf((int) ((Math.random() * 900000) + 100000));

        account.setResetPasswordToken(otp);
        account.setResetPasswordTokenExpiry(LocalDateTime.now().plusMinutes(15)); // Hết hạn sau 15 phút
        accountRepository.save(account);

        return otp;
    }

    @Override
    public void resetPassword(String email, String otp, String newPassword) {
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại"));

        if (account.getResetPasswordToken() == null || !account.getResetPasswordToken().equals(otp)) {
            throw new RuntimeException("Mã OTP không chính xác");
        }

        if (account.getResetPasswordTokenExpiry().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Mã OTP đã hết hạn");
        }

        account.setHashPassword(passwordEncoder.encode(newPassword));
        // Xóa OTP sau khi đổi mật khẩu thành công
        account.setResetPasswordToken(null);
        account.setResetPasswordTokenExpiry(null);
        accountRepository.save(account);
    }

    /**
     * [2.2] Tạo và lưu Refresh Token mới cho thiết bị.
     * Hiện tại được thay thế bởi logic trong authenticate() — giữ lại để tương thích ngược.
     */
    @Override
    @Transactional
    public String generateAndSaveRefreshToken(Account account, String deviceToken,
                                              String deviceType, String deviceName,
                                              String ipAddress, Boolean loggedIn) {
        // Bước 1: Đăng ký thiết bị qua UserDeviceService
        UserDevice device = userDeviceService.registerDevice(
                account, deviceToken, deviceType, deviceName, ipAddress);

        // Bước 2: Tạo Refresh Token
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());

        // Bước 3: Gắn token vào thiết bị và lưu
        device.setRefreshToken(refreshToken);
        userDeviceRepository.save(device);

        return refreshToken;
    }

    /**
     * [2.3] Tạo Access Token từ thông tin Account.
     */
    @Override
    public String generateAccessToken(Account account) {
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        return jwtUtils.generateAccessToken(userDetails, account.getId());
    }

    // =================================================================================
    // 3. ĐĂNG KÝ (REGISTER)
    // =================================================================================

    /**
     * [3.1] Đăng ký tài khoản mới.
     * Bước 1 — Validate trùng email/SĐT.
     * Bước 2 — Lấy Role USER và Currency VND mặc định.
     * Bước 3 — Tạo Account.
     * Bước 4 — Gửi thông báo cho Admin.
     */
    @Override
    @Transactional
    public Account register(RegisterRequest request) {
        // Bước 1: Validate trùng lặp
        if (request.getAccEmail() != null
                && accountRepository.existsByAccEmail(request.getAccEmail())) {
            throw new IllegalArgumentException("Email đã được sử dụng");
        }
        if (request.getAccPhone() != null
                && accountRepository.existsByAccPhone(request.getAccPhone())) {
            throw new IllegalArgumentException("Số điện thoại đã được sử dụng");
        }

        // Bước 2: Lấy Role và Currency mặc định
        Role userRole = roleRepository.findByRoleCode("ROLE_USER")
                .orElseThrow(() -> new IllegalStateException("Role USER không tồn tại trong hệ thống")); // Đổi RuntimeException
        Currency defaultCurrency = currencyRepository.findById("VND")
                .orElseThrow(() -> new IllegalStateException("Currency VND không tồn tại")); // Đổi RuntimeException

        // Bước 3: Tạo và lưu Account
        Account account = Account.builder()
                .accPhone(request.getAccPhone())
                .accEmail(request.getAccEmail())
                .hashPassword(passwordEncoder.encode(request.getPassword()))
                .role(userRole)
                .currency(defaultCurrency)
                .locked(false)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        Account savedAccount = accountRepository.save(account);

        // Bước 4: Thông báo cho Admin
        notifyAdminsAboutNewUser(savedAccount);

        return savedAccount;
    }

    // =================================================================================
    // 4. ĐĂNG XUẤT (LOGOUT)
    // =================================================================================

    /**
     * [4.1] Đăng xuất thiết bị theo device token.
     */
    @Override
    @Transactional
    public void logout(String deviceToken) {
        userDeviceService.logoutDevice(deviceToken);
    }

    // =================================================================================
    // 5. HELPER
    // =================================================================================

    /**
     * [5.1] Chuyển đổi Account → UserInfoDTO để đóng gói vào AuthResponse.
     */
    @Override
    @Transactional(readOnly = true)
    public UserInfoDTO convertToUserInfoDTO(Account account) {
        UserInfoDTO userInfo = new UserInfoDTO();
        userInfo.setId(account.getId());
        userInfo.setEmail(account.getAccEmail());
        userInfo.setPhone(account.getAccPhone());
        userInfo.setAvatarUrl(account.getAvatarUrl());
        userInfo.setIsLocked(account.getLocked());

        if (account.getCurrency() != null) {
            userInfo.setCurrencyCode(account.getCurrency().getCurrencyCode());
        }
        if (account.getRole() != null) {
            userInfo.setRoleId(account.getRole().getId()); // Dùng cho React: if (roleId === 1)
            userInfo.setRoleName(account.getRole().getRoleName());
            userInfo.setRoleCode(account.getRole().getRoleCode());
            if (account.getRole().getPermissions() != null) {
                Set<String> perCodes = account.getRole().getPermissions().stream()
                        .map(Permission::getPerCode)
                        .collect(Collectors.toSet());
                userInfo.setPermissions(perCodes);
            }
        }
        return userInfo;
    }

    /**
     * [5.2] Gửi thông báo type=4 (SYSTEM) cho tất cả Admin khi có user mới đăng ký.
     * Dùng NotificationMessages.newUserRegistered() để đảm bảo message chuẩn hóa.
     */
    private void notifyAdminsAboutNewUser(Account newUser) {
        // Bước 1: Tìm tất cả tài khoản Admin
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");

        // Bước 2: Lấy tên hiển thị của user mới (email hoặc SĐT)
        String userName = newUser.getAccEmail() != null
                ? newUser.getAccEmail()
                : newUser.getAccPhone();

        // Bước 3: Tạo nội dung thông báo từ template chuẩn
        NotificationContent msg = NotificationMessages.newUserRegistered(userName);

        // Bước 4: Gửi thông báo đến từng Admin
        for (Account admin : admins) {
            notificationService.createNotification(
                    admin,
                    msg.title(),
                    msg.content(),
                    NotificationType.SYSTEM,
                    Long.valueOf(newUser.getId()),
                    LocalDateTime.now()
            );
        }
    }
}
