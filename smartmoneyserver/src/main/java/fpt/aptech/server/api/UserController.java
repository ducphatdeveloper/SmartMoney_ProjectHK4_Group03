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
        return ResponseEntity.ok(ApiResponse.success(profile, "Profile retrieved successfully"));
    }
    @PatchMapping("/profile")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AccountDto>> updateProfile(
            @AuthenticationPrincipal Account currentUser,
            @Valid @RequestBody AccountDto dto) {
        AccountDto updatedProfile = userService.updateProfile(currentUser.getId(), dto);
        return ResponseEntity.ok(ApiResponse.success(updatedProfile, "Profile updated successfully"));
    }

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<String>> updateAvatar(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam("file") MultipartFile file) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(ApiResponse.error("File cannot be empty"));
        }

        try {
            String newAvatarUrl = userService.updateAvatar(currentUser.getId(), file);
            return ResponseEntity.ok(ApiResponse.success(newAvatarUrl, "Avatar updated successfully"));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error("Error uploading image to server: " + e.getMessage()));
        }
    }

    @PostMapping("/emergency-lock/send-otp")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> sendEmergencyLockOTP(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam String identityCard) {
        try {
            userService.sendEmergencyLockOTP(currentUser.getId(), identityCard);
            return ResponseEntity.ok(ApiResponse.success(null, "OTP code has been sent to your Gmail. Please check and enter the code to confirm account lock."));
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
            return ResponseEntity.ok(ApiResponse.success(null, "Your account has been successfully locked."));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(ApiResponse.error(e.getMessage()));
        }
    }
}