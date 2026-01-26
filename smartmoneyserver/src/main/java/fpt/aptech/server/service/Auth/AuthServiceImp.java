package fpt.aptech.server.service.Auth;

import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Permission;
import fpt.aptech.server.entity.Role;
import fpt.aptech.server.entity.UserDevice;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import fpt.aptech.server.utils.JwtUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class AuthServiceImp implements AuthService{
    @Autowired
    private AccountRepository accountRepository;
    @Autowired
    private UserDeviceRepository userDeviceRepository;
    @Autowired
    private JwtUtils jwtUtils;
    @Autowired
    private BCryptPasswordEncoder passwordEncoder;

    @Override
    @Transactional(readOnly = true)
    public Account login(String email, String password) {
        // 1. Tìm tài khoản theo email
        Account account = accountRepository.findByAccEmail(email)
                .orElseThrow(() -> new RuntimeException("Email không tồn tại"));

        // 2. Kiểm tra tài khoản có bị khóa không
        if (account.getLocked()) {
            throw new RuntimeException("Tài khoản hiện đang bị khóa");
        }

        // 3. So sánh mật khẩu thuần với bản hash trong DB
        if (!passwordEncoder.matches(password, account.getHashPassword())) {
            throw new RuntimeException("Mật khẩu không chính xác");
        }

        return account;
    }

    @Override
    @Transactional
    public String generateAndSaveRefreshToken(Account account, String deviceToken, String deviceType) {
        // 1. Tạo Refresh Token
        String refreshToken = UUID.randomUUID().toString();

        // 2. Tìm thiết bị cũ hoặc tạo mới
        UserDevice device = userDeviceRepository.findByDeviceToken(deviceToken)
                .orElse(new UserDevice());

        // 3. Cập nhật thông tin thiết bị
        device.setAccount(account);
        device.setDeviceToken(deviceToken);
        device.setDeviceType(deviceType);
        device.setRefreshToken(refreshToken);
        device.setLoggedIn(true);
        device.setRefreshTokenExpiredAt(LocalDateTime.now().plusDays(7));
        // FIX LỖI TẠI ĐÂY: Gán giá trị cho lastActive để không bị null
        device.setLastActive(LocalDateTime.now());

        userDeviceRepository.save(device);

        return refreshToken;
    }

    @Override
    public String generateAccessToken(Account account) {
        // Sử dụng email của account làm Subject cho JWT
        // vì email là duy nhất trong hệ thống của bạn
        return jwtUtils.generateToken(account.getAccEmail());
    }
    @Override
    @Transactional(readOnly = true)
    public UserInfoDTO convertToUserInfoDTO(Account account) {
        UserInfoDTO userInfo = new UserInfoDTO();

        // 1. Gán thông tin cá nhân
        userInfo.setId(account.getId());
        userInfo.setEmail(account.getAccEmail());
        userInfo.setPhone(account.getAccPhone());
        userInfo.setAvatarUrl(account.getAvatarUrl());

        // 2. Lấy tên Role
        if (account.getRole() != null) {
            userInfo.setRoleName(account.getRole().getRoleName()); // Truy cập lần 1 vào Role
            if (account.getRole().getPermissions() != null) {
                Set<String> perCodes = account.getRole().getPermissions().stream() // Truy cập lần 2 vào danh sách Permissions
                        .map(Permission::getPerCode)
                        .collect(Collectors.toSet());
                userInfo.setPermissions(perCodes);
            } else {
                // Nếu null, trả về một tập hợp rỗng thay vì để lỗi
                userInfo.setPermissions(java.util.Collections.emptySet());
            }
        }

        return userInfo;
    }

    @Autowired
    private fpt.aptech.server.repos.RoleRepository roleRepository; // Nhớ tạo Interface này nếu chưa có

    @Override
    public Account register(RegisterRequest registerRequest) {
        // 1. Kiểm tra email
        if (accountRepository.existsByAccEmail(registerRequest.getEmail())) {
            throw new RuntimeException("Email này đã được sử dụng");
        }

        // 2. Lấy Role mặc định (ID = 2 là ROLE_USER) từ DB
        // Việc này giúp đối tượng Role có đầy đủ data (Name, Permissions...)
        Role userRole = roleRepository.findById(2)
                .orElseThrow(() -> new RuntimeException("Lỗi hệ thống: Role USER không tồn tại"));

        // 3. Khởi tạo Account bằng Constructor rỗng và dùng Setter (An toàn nhất)
        Account account = new Account();
        account.setRole(userRole);
        account.setAccEmail(registerRequest.getEmail());
        account.setHashPassword(passwordEncoder.encode(registerRequest.getPassword()));
        account.setAccPhone(registerRequest.getPhone());
        account.setLocked(false); // Mặc định không khóa
        account.setCreatedAt(LocalDateTime.now());
        account.setUpdatedAt(LocalDateTime.now());

        // 4. Lưu và trả về
        return accountRepository.save(account);
    }

    @Override
    public void logout(String deviceToken) {
        // 1. Tìm thiết bị theo deviceToken
        userDeviceRepository.findByDeviceToken(deviceToken).ifPresent(device -> {
            // 2. Cập nhật trạng thái không còn đăng nhập
            device.setLoggedIn(false);

            // 3. Xóa Refresh Token để vô hiệu hóa phiên làm việc 🔑
            device.setRefreshToken(null);

            // 4. Lưu lại thay đổi vào database
            userDeviceRepository.save(device);
        });
    }
}
