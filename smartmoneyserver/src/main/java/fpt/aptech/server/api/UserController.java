package fpt.aptech.server.api;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.service.User.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}