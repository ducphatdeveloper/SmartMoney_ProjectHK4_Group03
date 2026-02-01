package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.RoleRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.utils.JwtUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
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

        // 3. Tạo/Cập nhật Refresh Token và thiết bị
        String refreshToken = generateAndSaveRefreshToken(
                account,
                loginRequest.getDeviceToken(),
                loginRequest.getDeviceType(),
                loginRequest.getDeviceName() != null ? loginRequest.getDeviceName() : "Unknown Device",
                ipAddress,
                true
        );

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
        // 1. Tạo Refresh Token (Sử dụng JWT để đồng bộ với logic bảo mật mới)
        UserDetails userDetails = userDetailsService.loadUserByUsername(account.getAccEmail());
        String refreshToken = jwtUtils.generateRefreshToken(userDetails, account.getId());

        // 2. Tìm thiết bị cũ hoặc tạo mới dựa trên deviceToken
        UserDevice device = userDeviceRepository.findByDeviceToken(deviceToken)
                .orElse(new UserDevice());

        // 3. Cập nhật thông tin chi tiết dựa trên thực thể UserDevice mới
        device.setAccount(account);
        device.setDeviceToken(deviceToken);
        device.setRefreshToken(refreshToken);
        device.setDeviceType(deviceType);
        device.setDeviceName(deviceName);
        device.setIpAddress(ipAddress);
        device.setLoggedIn(loggedIn != null ? loggedIn : true);
        device.setLastActive(LocalDateTime.now());

        // Thiết lập thời gian hết hạn cho Token (ví dụ: 7 ngày)
        device.setRefreshTokenExpiredAt(LocalDateTime.now().plusDays(7));

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

        if (account.getRole() != null) {
            userInfo.setRoleName(account.getRole().getRoleName());
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

        return accountRepository.save(account);
    }

    @Override
    @Transactional
    public void logout(String deviceToken) {
        // 1. Tìm thiết bị dựa trên Token duy nhất của thiết bị đó
        userDeviceRepository.findByDeviceToken(deviceToken).ifPresent(device -> {

            // 2. Cập nhật trạng thái đăng nhập về false
            device.setLoggedIn(false);

            // 3. Vô hiệu hóa Refresh Token bằng cách gán null
            device.setRefreshToken(null);

            // 4. Cập nhật thời điểm hoạt động cuối cùng
            device.setLastActive(LocalDateTime.now());

            // 5. Lưu thay đổi xuống Database
            userDeviceRepository.save(device);
        });
    }
}