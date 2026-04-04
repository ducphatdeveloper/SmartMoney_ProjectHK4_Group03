package fpt.aptech.server.api;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.User.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<AccountDto>> getProfile() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String email = authentication.getName(); // Email được set làm username trong UserDetails

        AccountDto profile = userService.getProfile(email);
        return ResponseEntity.ok(ApiResponse.success(profile, "Lấy thông tin cá nhân thành công"));
    }
    @PatchMapping("/profile")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AccountDto>> updateProfile(
            @AuthenticationPrincipal Account currentUser,
            @Valid @RequestBody AccountDto dto) {
        AccountDto updatedProfile = userService.updateProfile(currentUser.getId(), dto);
        return ResponseEntity.ok(ApiResponse.success(updatedProfile, "Cập nhật thông tin cá nhân thành công"));
    }

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<String>> updateAvatar(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam("file") MultipartFile file) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("File không được để trống"));
        }

        try {
            String newAvatarUrl = userService.updateAvatar(currentUser.getId(), file);
            return ResponseEntity.ok(ApiResponse.success(newAvatarUrl, "Cập nhật ảnh đại diện thành công"));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("Lỗi khi tải ảnh lên server: " + e.getMessage()));
        }
    }

    @PostMapping("/emergency-lock/send-otp")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> sendEmergencyLockOTP(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam String identityCard) {
        try {
            userService.sendEmergencyLockOTP(currentUser.getId(), identityCard);
            return ResponseEntity.ok(ApiResponse.success(null, "Mã OTP đã được gửi đến Gmail của bạn. Vui lòng kiểm tra và nhập mã để xác nhận khóa tài khoản."));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }

    @PostMapping("/emergency-lock/verify-and-lock")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> verifyAndLockAccount(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam String otpCode) {
        try {
            userService.verifyAndLockAccount(currentUser.getId(), otpCode);
            return ResponseEntity.ok(ApiResponse.success(null, "Tài khoản của bạn đã được khóa khẩn cấp thành công."));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }
}