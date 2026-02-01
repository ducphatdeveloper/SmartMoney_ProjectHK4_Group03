package fpt.aptech.server.api;

import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.Auth.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest loginRequest,
            HttpServletRequest request) {

        // 1. Lấy thông tin bổ sung từ request
        String ipAddress = request.getRemoteAddr();

        // 2. Gọi Service xử lý nghiệp vụ xác thực tập trung
        AuthResponse authResponse = authService.authenticate(loginRequest, ipAddress);

        // 3. Trả về kết quả chuẩn hóa qua ApiResponse
        return ResponseEntity.ok(ApiResponse.success(authResponse, "Đăng nhập thành công"));
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<UserInfoDTO>> register(
            @Valid @RequestBody RegisterRequest registerRequest) {

        Account account = authService.register(registerRequest);
        UserInfoDTO userInfo = authService.convertToUserInfoDTO(account);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(userInfo, "Đăng ký tài khoản thành công"));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@RequestParam String deviceToken) {
        authService.logout(deviceToken);
        return ResponseEntity.ok(ApiResponse.success(null, "Đăng xuất thành công"));
    }
}