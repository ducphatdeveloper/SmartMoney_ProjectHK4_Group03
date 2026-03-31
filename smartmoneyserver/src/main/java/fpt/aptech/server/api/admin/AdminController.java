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

    // 1. Quản lý người dùng - Lấy danh sách & Lọc (Khớp với fetchUsers ở React)
    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<PageResponse<AccountDto>>> getUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean locked,
            @RequestParam(required = false) String onlineStatus,
            Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getUsers(search, locked, onlineStatus, pageable)));
    }

    // 2. Khóa tài khoản (Khớp với confirmAction ở React)
    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> lockAccount(@PathVariable Integer id) {
        adminService.lockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã bị khóa và tất cả phiên đăng nhập đã được thu hồi"));
    }

    // 3. Mở khóa tài khoản (Khớp với confirmAction ở React)
    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> unlockAccount(@PathVariable Integer id) {
        adminService.unlockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã được mở khóa thành công"));
    }

    // 4. Widget tổng quan (Dashboard Overview) - Fix lỗi 404 bằng cách map đúng /stats
    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDashboardOverview()));
    }

    // 5. Chi tiết số lượng Online Users (Dùng cho biểu đồ thời gian thực)
    @GetMapping("/analytics/online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Long>> getOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.countOnlineUsers()));
    }

    // 5.1 Lấy toàn bộ danh sách người dùng đang trực tuyến (Live View)
    @GetMapping("/analytics/live-online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<AccountDto>>> getAllLiveOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllLiveOnlineUsers()));
    }


    // 6. Phân tích tài chính hệ thống - Trả về breakdown % danh mục cha/con (100% Volume)
    @GetMapping("/system/transaction-stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSystemTransactionStats(
            @RequestParam(defaultValue = "MONTHLY") String rangeMode) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getSystemTransactionStats(rangeMode)));
    }

    // 7. Bảo mật: Kích hoạt quét và cảnh báo giao dịch bất thường
    @PostMapping("/system/notify-abnormal")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> notifyAbnormalTransactions(
            @RequestParam BigDecimal threshold) {
        adminService.notifyAbnormalTransactions(threshold);
        return ResponseEntity.ok(ApiResponse.success("Đã quét và gửi thông báo đến các giao dịch bất thường"));
    }

    // 7.1 Lấy danh sách người dùng có giao dịch bất thường để hiển thị lên Dashboard
    @GetMapping("/system/abnormal-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getAbnormalUsers(
            @RequestParam BigDecimal threshold) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAbnormalTransactionUsers(threshold)));
    }

    // 7.2 Bảo mật: Thủ công kích hoạt quét và thu hồi các phiên đăng nhập ngoại tuyến (Auto Logout)
    @PostMapping("/system/auto-logout")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> handleAutoLogout() {
        adminService.handleAutoLogout();
        return ResponseEntity.ok(ApiResponse.success("Đã thực hiện quét và thu hồi các phiên đăng nhập đã ngoại tuyến quá hạn"));
    }

    // 8. Thông báo hệ thống cho Admin - Lấy các sự kiện quan trọng (SYSTEM notifications)
    @GetMapping("/notifications/{adminId}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Notification>>> getAdminNotifications(@PathVariable Integer adminId) {
        // Lưu ý: Logic đã được cập nhật để lấy thông báo loại SYSTEM trên toàn hệ thống 
        // thay vì thông báo cá nhân, giúp Admin giám sát các sự kiện quan trọng.
        return ResponseEntity.ok(ApiResponse.success(adminService.getAdminNotifications(adminId)));
    }
}