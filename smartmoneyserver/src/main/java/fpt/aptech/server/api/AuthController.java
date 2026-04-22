package fpt.aptech.server.api;

import fpt.aptech.server.dto.request.ForgotPasswordRequest;
import fpt.aptech.server.dto.request.LoginRequest;
import fpt.aptech.server.dto.request.ResetPasswordRequest;
import fpt.aptech.server.dto.request.RegisterRequest;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.response.AuthResponse;
import fpt.aptech.server.dto.UserInfoDTO;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.Auth.AuthService;
import fpt.aptech.server.service.emailsender.EmailService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    @Autowired
    private EmailService emailService;

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest loginRequest,
            HttpServletRequest request) {

        String ipAddress = getClientIp(request);
        AuthResponse authResponse = authService.authenticate(loginRequest, ipAddress);
        return ResponseEntity.ok(ApiResponse.success(authResponse, "Đăng nhập thành công"));
    }

    @PostMapping("/google-login")
    public ResponseEntity<ApiResponse<AuthResponse>> googleLogin(
            @RequestBody Map<String, String> payload,
            HttpServletRequest request) {
        
        String idToken = payload.get("idToken");
        String deviceToken = payload.get("deviceToken");
        String deviceType = payload.getOrDefault("deviceType", "ANDROID");
        String deviceName = payload.getOrDefault("deviceName", "Google Device");
        
        String ipAddress = getClientIp(request);
        AuthResponse authResponse = authService.authenticateGoogle(idToken, deviceToken, deviceType, deviceName, ipAddress);
        
        return ResponseEntity.ok(ApiResponse.success(authResponse, "Đăng nhập Google thành công"));
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<UserInfoDTO>> register(
            @Valid @RequestBody RegisterRequest registerRequest) {

        Account account = authService.register(registerRequest);
        UserInfoDTO userInfo = authService.convertToUserInfoDTO(account);

        String subject = "Chào mừng bạn đến với SmartMoney";
        String htmlBody = "<h3>Đăng ký thành công!</h3><p>Cảm ơn bạn đã tạo tài khoản. Hãy bắt đầu quản lý chi tiêu của mình ngay hôm nay.</p>";
        emailService.sendHtmlReport(account.getAccEmail(), subject, htmlBody);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(userInfo, "Đăng ký tài khoản thành công"));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        String otp = authService.generateResetToken(request.getEmail());
        emailService.sendOtp(request.getEmail(), otp);
        return ResponseEntity.ok(ApiResponse.success(null, "Mã xác thực đã được gửi đến email của bạn"));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<Void>> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request.getEmail(), request.getOtp(), request.getNewPassword());
        return ResponseEntity.ok(ApiResponse.success(null, "Đặt lại mật khẩu thành công"));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@RequestParam String deviceToken) {
        authService.logout(deviceToken);
        return ResponseEntity.ok(ApiResponse.success(null, "Đăng xuất thành công"));
    }

    private String getClientIp(HttpServletRequest request) {
        String ipAddress = request.getHeader("X-Forwarded-For");
        if (ipAddress == null || ipAddress.isEmpty() || "unknown".equalsIgnoreCase(ipAddress)) {
            ipAddress = request.getRemoteAddr();
        }
        if (ipAddress != null && ipAddress.contains(",")) {
            ipAddress = ipAddress.split(",")[0].trim();
        }
        return ipAddress;
    }
}
