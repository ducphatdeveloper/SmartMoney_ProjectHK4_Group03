package fpt.aptech.server.api;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.User.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/profile")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<AccountDto>> getProfile(@AuthenticationPrincipal Account currentUser) {
        // Lấy thông tin từ email của currentUser để đảm bảo dữ liệu mới nhất
        AccountDto profile = userService.getProfile(currentUser.getAccEmail());
        return ResponseEntity.ok(ApiResponse.success(profile, "Lấy thông tin cá nhân thành công"));
    }

    /**
     * Cập nhật ảnh đại diện của người dùng.
     * Nhận file trực tiếp từ người dùng.
     */
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
}