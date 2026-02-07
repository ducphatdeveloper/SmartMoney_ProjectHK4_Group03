package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.repos.*;
import fpt.aptech.server.service.Notification.NotificationService;
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

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private UserDeviceRepository userDeviceRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private UserDeviceService userDeviceService;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private UserDetailsService userDetailsService;

    @Autowired
    private CurrencyRepository currencyRepository;

    @Override
    public AuthResponse authenticate(LoginRequest loginRequest, String ipAddress) {
        // 1. Xác thực tài khoản
        Account account = login(loginRequest.getUsername(), loginRequest.getPassword());

        // 2. Tạo Access Token
        String accessToken = generateAccessToken(account);

        // 3. Tạo/Cập nhật Refresh Token và thiết bị thông qua UserDeviceService
        UserDevice device = userDeviceService.registerDevice(
                account,
                loginRequest.getDeviceToken(),
                loginRequest.getDeviceType(),
                loginRequest.getDeviceName() != null ? loginRequest.getDeviceName() : "Unknown Device",
                ipAddress
        );
        
        // Tạo Refresh Token (Sử dụng JWT)
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());
        
        // Cập nhật Refresh Token vào thiết bị
        device.setRefreshToken(refreshToken);
        userDeviceRepository.save(device);

        // 4. Chuyển đổi thông tin người dùng sang DTO
        UserInfoDTO userInfo = convertToUserInfoDTO(account);

        // 5. Đóng gói vào AuthResponse 📦
        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .userId(userInfo.getId())
                .accPhone(userInfo.getPhone())
                .accEmail(userInfo.getEmail())
                .avatarUrl(userInfo.getAvatarUrl())
                .currency(userInfo.getCurrencyCode())
                .roleId(userInfo.getRoleId()) // <--- THÊM DÒNG NÀY
                .roleCode(userInfo.getRoleCode())
                .roleName(userInfo.getRoleName())
                .permissions(userInfo.getPermissions())
                .loginAt(LocalDateTime.now())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public Account login(String username, String password) {
        // Tìm tài khoản bằng username (có thể là email hoặc phone)
        Account account = accountRepository.findByUsernameOrEmail(username)
                .orElseThrow(() -> new RuntimeException("Tài khoản không tồn tại"));

        if (account.getLocked()) {
            throw new RuntimeException("Tài khoản hiện đang bị khóa");
        }

        if (!passwordEncoder.matches(password, account.getHashPassword())) {
            throw new RuntimeException("Mật khẩu không chính xác");
        }

        return account;
    }

    @Override
    @Transactional
    public String generateAndSaveRefreshToken(Account account, String deviceToken, String deviceType, String deviceName, String ipAddress, Boolean loggedIn) {
        // Phương thức này hiện tại được thay thế bởi logic trong authenticate sử dụng UserDeviceService
        // Tuy nhiên vẫn giữ lại nếu có nơi khác gọi, hoặc có thể xóa đi nếu không dùng.
        // Để đảm bảo tính nhất quán, ta sẽ gọi lại UserDeviceService ở đây.
        
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
            userInfo.setRoleId(account.getRole().getId()); // <--- THÊM DÒNG NÀY vì trang login bên react của Nam gọi if (serverData.roleId === 1)
            userInfo.setRoleName(account.getRole().getRoleName());
            userInfo.setRoleCode(account.getRole().getRoleCode()); //them role code
            if (account.getRole().getPermissions() != null) {
                Set<String> perCodes = account.getRole().getPermissions().stream()
                        .map(Permission::getPerCode)
                        .collect(Collectors.toSet());
                userInfo.setPermissions(perCodes);
            }
        }
        return userInfo;
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
                .orElseThrow(() -> new RuntimeException("Role USER không tồn tại trong hệ thống"));

        // 3. Lấy Currency mặc định (VND)
        Currency defaultCurrency = currencyRepository.findById("VND")
                .orElseThrow(() -> new RuntimeException("Currency VND không tồn tại"));

        // 4. Tạo Account mới
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

        // 5. Gửi thông báo cho Admin
        notifyAdminsAboutNewUser(savedAccount);

        return savedAccount;
    }

    private void notifyAdminsAboutNewUser(Account newUser) {
        // Tìm tất cả tài khoản có role là ADMIN
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");

        String userName = newUser.getAccEmail() != null ? newUser.getAccEmail() : newUser.getAccPhone();
        String message = "Người dùng mới " + userName + " vừa đăng ký tài khoản.";

        for (Account admin : admins) {
            notificationService.createNotification(
                    admin,
                    "Người dùng mới đăng ký",
                    message,
                    4, // 4: SYSTEM
                    Long.valueOf(newUser.getId())
            );
        }
    }

    @Override
    @Transactional
    public void logout(String deviceToken) {
        // Sử dụng UserDeviceService để logout
        userDeviceService.logoutDevice(deviceToken);
    }
}