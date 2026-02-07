package fpt.aptech.server.api.admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.service.Admin.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<PageResponse<AccountDto>> getUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean locked,
            @RequestParam(required = false) String onlineStatus,
            Pageable pageable) {
        return ResponseEntity.ok(adminService.getUsers(search, locked, onlineStatus, pageable));
    }

    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<String> lockAccount(@PathVariable Integer id) {
        adminService.lockAccount(id);
        return ResponseEntity.ok("Account locked successfully.");
    }

    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<String> unlockAccount(@PathVariable Integer id) {
        adminService.unlockAccount(id);
        return ResponseEntity.ok("Account unlocked successfully.");
    }

    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<Map<String, Object>> getStats() {
        return ResponseEntity.ok(adminService.getStats());
    }

    // API lấy thông báo của Admin (dựa trên accId của Admin đang đăng nhập)
    @GetMapping("/notifications/{adminId}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<List<Notification>> getAdminNotifications(@PathVariable Integer adminId) {
        return ResponseEntity.ok(adminService.getAdminNotifications(adminId));
    }
}