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

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    /**
     * [1] Quản lý người dùng: Lấy danh sách phân trang và lọc theo trạng thái Online/Locked.
     */
    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<PageResponse<AccountDto>>> getUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean locked,
            @RequestParam(required = false) String onlineStatus,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getUsers(search, locked, onlineStatus, pageable)));
    }

    /**
     * [2] Khóa tài khoản: Chuyển trạng thái locked=1 và thu hồi toàn bộ Refresh Token (Force Logout).
     */
    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> lockAccount(@PathVariable Integer id) {
        adminService.lockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã bị khóa và tất cả phiên đăng nhập đã được thu hồi thành công"));
    }

    /**
     * [3] Mở khóa tài khoản: Khôi phục quyền truy cập cho người dùng.
     */
    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> unlockAccount(@PathVariable Integer id) {
        adminService.unlockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã được mở khóa"));
    }

    /**
     * [4] Thống kê tổng quan (Dashboard Widgets): Tổng user, giao dịch, online users, tăng trưởng.
     */
    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDashboardOverview()));
    }

    /**
     * [5] Đếm số lượng người dùng trực tuyến (Real-time count).
     */
    @GetMapping("/analytics/online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Long>> getOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.countOnlineUsers()));
    }

    /**
     * [5.1] Danh sách chi tiết người dùng đang trực tuyến (Real-time Live View).
     */
    @GetMapping("/analytics/live-online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<AccountDto>>> getAllLiveOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllLiveOnlineUsers()));
    }

    /**
     * [6] Phân tích tỷ trọng tài chính: Tính % dựa trên tổng khối lượng (Thu + Chi = 100%).
     */
    @GetMapping("/system/transaction-stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSystemTransactionStats(
            @RequestParam(defaultValue = "MONTHLY") String rangeMode) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getSystemTransactionStats(rangeMode)));
    }

    /**
     * [7] Bảo mật: Quét và gửi thông báo cảnh báo cho các giao dịch vượt ngưỡng threshold.
     */
    @PostMapping("/system/notify-abnormal")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> notifyAbnormalTransactions(
            @RequestParam BigDecimal threshold) {
        adminService.notifyAbnormalTransactions(threshold);
        return ResponseEntity.ok(ApiResponse.success("Đã hoàn tất quét và gửi cảnh báo giao dịch bất thường"));
    }

    /**
     * [7.1] Đối soát Dashboard: Lấy danh sách người dùng và chi tiết các giao dịch bất thường.
     */
    @GetMapping("/system/abnormal-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getAbnormalUsers(
            @RequestParam BigDecimal threshold) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAbnormalTransactionUsers(threshold)));
    }

    /**
     * [7.2] Quản trị phiên: Thủ công thu hồi các phiên đăng nhập "treo" (ngoại tuyến > 30 phút).
     */
    @PostMapping("/system/auto-logout")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> handleAutoLogout() {
        adminService.handleAutoLogout();
        return ResponseEntity.ok(ApiResponse.success("Đã dọn dẹp và thu hồi các phiên đăng nhập ngoại tuyến quá hạn"));
    }

    /**
     * [8] Thông báo hệ thống: Lấy các sự kiện quan trọng (SYSTEM) để Admin giám sát.
     */
    @GetMapping("/notifications/{adminId}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Notification>>> getAdminNotifications(@PathVariable Integer adminId) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAdminNotifications(adminId)));
    }
}