package fpt.aptech.server.api;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.Auth.AuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/login")
    @Transactional(readOnly = true) // THÊM DÒNG NÀY: Giữ session mở để load dữ liệu Role
    public ResponseEntity<AuthResponse> login(@RequestBody LoginRequest loginRequest) {
        // 1. Xác thực thông tin đăng nhập
        Account account = authService.login(loginRequest.getEmail(), loginRequest.getPassword());

        // 2. Tạo tokens
        String refreshToken = authService.generateAndSaveRefreshToken(
                account,
                loginRequest.getDeviceToken(),
                loginRequest.getDeviceType()
        );
        String accessToken = authService.generateAccessToken(account);

        // 3. Chuyển đổi sang DTO (Lúc này Hibernate sẽ load được Role mà không bị lỗi)
        UserInfoDTO userInfo = authService.convertToUserInfoDTO(account);
        return ResponseEntity.ok(new AuthResponse(accessToken, refreshToken, userInfo));
    }

    @PostMapping("/register")
    public ResponseEntity<UserInfoDTO> register(@RequestBody RegisterRequest registerRequest) {
        // 1. Xử lý đăng ký (kiểm tra trùng lặp, mã hóa mật khẩu, lưu DB)
        Account account = authService.register(registerRequest);

        // 2. Chỉ trả về thông tin cần thiết (không trả về mật khẩu)
        UserInfoDTO userInfo = authService.convertToUserInfoDTO(account);
        return ResponseEntity.status(HttpStatus.CREATED).body(userInfo);
    }

    @PostMapping("/logout")
    public ResponseEntity<String> logout(@RequestParam String deviceToken) {
        authService.logout(deviceToken);
        return ResponseEntity.ok("Đăng xuất thành công");
    }
}