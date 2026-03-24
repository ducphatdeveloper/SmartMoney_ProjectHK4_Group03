package fpt.aptech.server.api.admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.dto.response.ApiResponse;
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

    // 1. Quản lý người dùng - Lấy danh sách & Lọc (Khớp với fetchUsers ở React)
    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<PageResponse<AccountDto>> getUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean locked,
            @RequestParam(required = false) Boolean online, // React gửi true/false/null
            Pageable pageable) {

        // Chuyển đổi Boolean từ React thành String cho Service logic
        String onlineStatus = null;
        if (Boolean.TRUE.equals(online)) {
            onlineStatus = "ONLINE";
        } else if (Boolean.FALSE.equals(online)) {
            onlineStatus = "OFFLINE";
        }

        return ResponseEntity.ok(adminService.getUsers(search, locked, onlineStatus, pageable));
    }

    // 2. Khóa tài khoản (Khớp với confirmAction ở React)
    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> lockAccount(@PathVariable Integer id) {
        // Lưu ý: Nếu Service yêu cầu adminId, cần lấy từ SecurityContext.
        // Ở đây giả định Service chỉ cần userId hoặc tự lấy context.
        adminService.lockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Khóa tài khoản thành công"));
    }

    // 3. Mở khóa tài khoản (Khớp với confirmAction ở React)
    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> unlockAccount(@PathVariable Integer id) {
        adminService.unlockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Mở khóa tài khoản thành công"));
    }

    // 4. Thống kê tổng quan (Khớp với fetchStats ở React)
    // React mong đợi object thuần: { totalUsers: ..., totalTransactions: ... }
    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<Map<String, Object>> getStats() {
        return ResponseEntity.ok(adminService.getStats());
    }

    // 5. Số lượng Online Users thực tế (Khớp với fetchStats ở React - phần activeDevices)
    // React mong đợi ApiResponse: res.data.data
    @GetMapping("/analytics/online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Long>> getOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.countOnlineUsers()));
    }

    // 6. Biểu đồ giao dịch (Khớp với fetchTransactionStats ở React)
    // React mong đợi ApiResponse: res.data.data
    @GetMapping("/system/transaction-stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSystemTransactionStats(
            @RequestParam(defaultValue = "MONTHLY") String rangeMode) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getSystemTransactionStats(rangeMode)));
    }

    // 7. Cảnh báo ngân sách (Khớp với fetchTransactionStats ở React)
    // React mong đợi ApiResponse: res.data.data
    @GetMapping("/system/overspent-budgets")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getSystemOverspentBudgets(
            @RequestParam(defaultValue = "MONTHLY") String rangeMode) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getSystemOverspentBudgets(rangeMode)));
    }

    // 8. Thông báo của Admin (Khớp với fetchNotifications ở React)
    // React mong đợi mảng JSON trực tiếp (res.data)
    @GetMapping("/notifications/{adminId}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<List<Notification>> getAdminNotifications(@PathVariable Integer adminId) {
        // Giả định phương thức service tên là getNotifications
        return ResponseEntity.ok(adminService.getAdminNotifications(adminId));
    }
}