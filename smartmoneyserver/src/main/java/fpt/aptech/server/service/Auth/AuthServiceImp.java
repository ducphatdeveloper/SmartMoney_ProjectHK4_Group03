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
import fpt.aptech.server.service.emailsender.EmailService;
import fpt.aptech.server.utils.JwtUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@Slf4j
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
    @Autowired private EmailService         emailService;

    private final Map<String, OtpData> otpCache = new ConcurrentHashMap<>();

    private static class OtpData {
        private final String otp;
        private final LocalDateTime expiry;
        public OtpData(String otp, LocalDateTime expiry) {
            this.otp = otp;
            this.expiry = expiry;
        }
        public String getOtp() { return otp; }
        public LocalDateTime getExpiry() { return expiry; }
    }

    @Override
    public AuthResponse authenticate(LoginRequest loginRequest, String ipAddress) {
        Account account = login(loginRequest.getUsername(), loginRequest.getPassword());
        return createAuthResponse(account, loginRequest.getDeviceToken(), loginRequest.getDeviceType(), 
                loginRequest.getDeviceName() != null ? loginRequest.getDeviceName() : "Unknown Device", ipAddress);
    }

    @Override
    @Transactional
    public AuthResponse authenticateGoogle(String idToken, String deviceToken, String deviceType, String deviceName, String ipAddress) {
        log.info("[GoogleAuth] Bắt đầu xác thực Google ID Token...");
        
        String googleVerifyUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken;
        RestTemplate restTemplate = new RestTemplate();
        Map<String, Object> response;
        try {
            response = restTemplate.getForObject(googleVerifyUrl, Map.class);
        } catch (Exception e) {
            log.error("[GoogleAuth] Lỗi mạng khi gọi Google API: {}", e.getMessage());
            throw new IllegalArgumentException("Không thể kết nối tới Google để xác thực. Vui lòng thử lại.");
        }

        if (response == null || response.containsKey("error")) {
            log.error("[GoogleAuth] Google API từ chối Token: {}", response != null ? response.get("error_description") : "null");
            throw new IllegalArgumentException("Đăng nhập Google thất bại: Token không hợp lệ hoặc đã hết hạn.");
        }

        String email = (String) response.get("email");
        String name = (String) response.get("name");
        String picture = (String) response.get("picture");
        log.info("[GoogleAuth] Xác thực thành công cho email: {}", email);

        Account account = accountRepository.findByAccEmail(email).orElseGet(() -> {
            log.info("[GoogleAuth] Tạo tài khoản mới cho user Google: {}", email);
            Role userRole = roleRepository.findByRoleCode("ROLE_USER")
                    .orElseThrow(() -> new IllegalStateException("Hệ thống chưa cấu hình ROLE_USER"));
            Currency defaultCurrency = currencyRepository.findById("VND")
                    .orElseThrow(() -> new IllegalStateException("Hệ thống chưa cấu hình Currency VND"));

            Account newAcc = Account.builder()
                    .accEmail(email)
                    .fullname(name)
                    .hashPassword(passwordEncoder.encode("GOOGLE_AUTH_" + UUID.randomUUID()))
                    .avatarUrl(picture)
                    .role(userRole)
                    .currency(defaultCurrency)
                    .locked(false)
                    .createdAt(LocalDateTime.now())
                    .updatedAt(LocalDateTime.now())
                    .build();
            
            Account saved = accountRepository.save(newAcc);
            
            // Gửi email chào mừng ngay khi đăng ký qua Google thành công
            try {
                String subject = "Chào mừng bạn đến với SmartMoney";
                String htmlBody = "<h3>Đăng ký thành công qua Google!</h3><p>Chào <b>" + name + "</b>, cảm ơn bạn đã tham gia SmartMoney. Hãy bắt đầu quản lý tài chính hiệu quả ngay hôm nay.</p>";
                emailService.sendHtmlReport(saved.getAccEmail(), subject, htmlBody);
            } catch (Exception e) {
                log.warn("[GoogleAuth] Không thể gửi email chào mừng tới {}: {}", email, e.getMessage());
            }

            notifyAdminsAboutNewUser(saved);
            return saved;
        });

        if (Boolean.TRUE.equals(account.getLocked())) {
            throw new IllegalStateException("Tài khoản Google này hiện đang bị khóa");
        }

        return createAuthResponse(account, deviceToken, deviceType, deviceName, ipAddress);
    }

    private AuthResponse createAuthResponse(Account account, String deviceToken, String deviceType, String deviceName, String ipAddress) {
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        
        String accessToken = jwtUtils.generateAccessToken(userDetails, account.getId());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());

        UserDevice device = userDeviceService.registerDevice(account, deviceToken, deviceType, deviceName, ipAddress);
        device.setRefreshToken(refreshToken);
        userDeviceRepository.save(device);

        UserInfoDTO userInfo = convertToUserInfoDTO(account);
        
        return AuthResponse.builder()
                .userId(userInfo.getId())
                .accPhone(userInfo.getPhone())
                .accEmail(userInfo.getEmail())
                .avatarUrl(userInfo.getAvatarUrl())
                .currency(userInfo.getCurrencyCode())
                .roleId(userInfo.getRoleId())
                .roleCode(userInfo.getRoleCode())
                .roleName(userInfo.getRoleName())
                .permissions(userInfo.getPermissions())
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .accessTokenExpiry(3600000L)
                .refreshTokenExpiry(86400000L)
                .loginAt(LocalDateTime.now())
                .message("Đăng nhập thành công")
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public Account login(String username, String password) {
        Account account = accountRepository.findByUsernameOrEmail(username)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));
        if (Boolean.TRUE.equals(account.getLocked())) {
            throw new IllegalStateException("Tài khoản hiện đang bị khóa");
        }
        if (!passwordEncoder.matches(password, account.getHashPassword())) {
            throw new IllegalArgumentException("Mật khẩu không chính xác");
        }
        return account;
    }

    @Override
    public String generateResetToken(String username) {
        accountRepository.findByUsernameOrEmail(username)
                .orElseThrow(() -> new RuntimeException("Tài khoản không tồn tại trong hệ thống"));
        String otp = String.valueOf((int) ((Math.random() * 900000) + 100000));
        LocalDateTime expiry = LocalDateTime.now().plusMinutes(15);
        otpCache.put(username, new OtpData(otp, expiry));
        return otp;
    }

    @Override
    public void resetPassword(String username, String otp, String newPassword) {
        OtpData storedOtp = otpCache.get(username);
        if (storedOtp == null || !storedOtp.getOtp().equals(otp)) {
            throw new RuntimeException("Mã OTP không chính xác hoặc không tồn tại");
        }
        if (storedOtp.getExpiry().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Mã OTP đã hết hạn");
        }
        Account account = accountRepository.findByUsernameOrEmail(username)
                .orElseThrow(() -> new RuntimeException("Tài khoản không tồn tại"));
        account.setHashPassword(passwordEncoder.encode(newPassword));
        accountRepository.save(account);
        otpCache.remove(username);
    }

    @Override
    @Transactional
    public String generateAndSaveRefreshToken(Account account, String deviceToken,
                                              String deviceType, String deviceName,
                                              String ipAddress, Boolean loggedIn) {
        UserDevice device = userDeviceService.registerDevice(account, deviceToken, deviceType, deviceName, ipAddress);
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());
        device.setRefreshToken(refreshToken);
        userDeviceRepository.save(device);
        return refreshToken;
    }

    @Override
    public String generateAccessToken(Account account) {
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        return jwtUtils.generateAccessToken(userDetails, account.getId());
    }

    @Override
    @Transactional
    public Account register(RegisterRequest request) {
        if (request.getAccEmail() != null && accountRepository.existsByAccEmail(request.getAccEmail())) {
            throw new IllegalArgumentException("Email đã được sử dụng");
        }
        if (request.getAccPhone() != null && accountRepository.existsByAccPhone(request.getAccPhone())) {
            throw new IllegalArgumentException("Số điện thoại đã được sử dụng");
        }
        Role userRole = roleRepository.findByRoleCode("ROLE_USER")
                .orElseThrow(() -> new IllegalStateException("Role USER không tồn tại"));
        Currency defaultCurrency = currencyRepository.findById("VND")
                .orElseThrow(() -> new IllegalStateException("Currency VND không tồn tại"));
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
        notifyAdminsAboutNewUser(savedAccount);
        return savedAccount;
    }

    @Override
    @Transactional
    public void logout(String deviceToken) {
        userDeviceService.logoutDevice(deviceToken);
    }

    @Override
    @Transactional(readOnly = true)
    public UserInfoDTO convertToUserInfoDTO(Account account) {
        UserInfoDTO userInfo = new UserInfoDTO();
        userInfo.setId(account.getId());
        userInfo.setEmail(account.getAccEmail());
        userInfo.setPhone(account.getAccPhone());
        userInfo.setAvatarUrl(account.getAvatarUrl());
        userInfo.setIsLocked(account.getLocked());
        if (account.getCurrency() != null) userInfo.setCurrencyCode(account.getCurrency().getCurrencyCode());
        if (account.getRole() != null) {
            userInfo.setRoleId(account.getRole().getId());
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

    private void notifyAdminsAboutNewUser(Account newUser) {
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
        String userName = newUser.getAccEmail() != null ? newUser.getAccEmail() : newUser.getAccPhone();
        NotificationContent msg = NotificationMessages.newUserRegistered(userName);
        for (Account admin : admins) {
            notificationService.createNotification(admin, msg.title(), msg.content(), NotificationType.SYSTEM, Long.valueOf(newUser.getId()), LocalDateTime.now());
        }
    }
}
