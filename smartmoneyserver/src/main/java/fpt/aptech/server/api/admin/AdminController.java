package fpt.aptech.server.api.admin;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.TransactionDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.dto.contact.ContactRequestResolveRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.service.Admin.AdminService;
import fpt.aptech.server.service.contact.ContactRequestService;
import jakarta.validation.Valid;
import org.springframework.data.web.PageableDefault;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final ContactRequestService contactRequestService;

    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<PageResponse<AccountDto>>> getUsers(
            @RequestParam(value = "search", required = false) String search,
            @RequestParam(value = "locked", required = false) Boolean locked,
            @RequestParam(value = "onlineStatus", required = false) String onlineStatus,
            @PageableDefault(size = 8) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getUsers(search, locked, onlineStatus, pageable)));
    }

    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> lockAccount(@PathVariable("id") Integer id) {
        adminService.lockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã bị khóa."));
    }

    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> unlockAccount(@PathVariable("id") Integer id) {
        adminService.unlockAccount(id);
        return ResponseEntity.ok(ApiResponse.success("Tài khoản đã được mở khóa."));
    }

    @GetMapping("/users/{id}/insights")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getUserFinancialInsights(@PathVariable("id") Integer id) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getUserFinancialInsights(id)));
    }

    @GetMapping("/users/{id}/transactions")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<PageResponse<TransactionDto>>> getUserTransactions(
            @PathVariable("id") Integer id,
            @RequestParam(value = "deletedStatus", defaultValue = "ACTIVE") String deletedStatus,
            @RequestParam(value = "type", required = false) String type,
            @PageableDefault(size = 5) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getUserTransactions(id, pageable, deletedStatus, type)));
    }

    @GetMapping("/users/{id}/transactions/all")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<TransactionDto>>> getAllUserTransactions(
            @PathVariable("id") Integer id,
            @RequestParam(value = "deletedStatus", defaultValue = "ACTIVE") String deletedStatus,
            @RequestParam(value = "type", required = false) String type) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAllUserTransactions(id, deletedStatus, type)));
    }

    /**
     * [MỚI] Theo dõi toàn bộ giao dịch đã xóa mềm của tất cả người dùng trên hệ thống.
     * Tận dụng View vAdminDeletedTransactions.
     */
    @GetMapping("/transactions/deleted-global")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getGlobalDeletedTransactions() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getGlobalDeletedTransactions()));
    }

    @PatchMapping("/transactions/{id}/restore")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> restoreTransaction(@PathVariable("id") Long id) {
        adminService.restoreTransaction(id);
        return ResponseEntity.ok(ApiResponse.success("Giao dịch đã được khôi phục thành công."));
    }

    @PatchMapping("/users/{userId}/transactions/restore-all")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> restoreAllUserTransactions(@PathVariable("userId") Integer userId) {
        adminService.restoreAllUserTransactions(userId);
        return ResponseEntity.ok(ApiResponse.success("Tất cả giao dịch của người dùng đã được khôi phục."));
    }

    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(adminService.getDashboardOverview()));
    }

    @GetMapping("/system/transaction-stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSystemTransactionStats(
            @RequestParam(value = "startDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endDate) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getSystemTransactionStats(startDate, endDate)));
    }

    @GetMapping("/analytics/online-users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Long>> getOnlineUsers() {
        return ResponseEntity.ok(ApiResponse.success(adminService.countOnlineUsers()));
    }

    @PostMapping("/system/auto-logout")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<String>> handleAutoLogout() {
        adminService.handleAutoLogout();
        return ResponseEntity.ok(ApiResponse.success("Đã thu hồi phiên quá hạn."));
    }

    @GetMapping("/notifications/{adminId}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<Notification>>> getAdminNotifications(@PathVariable("adminId") Integer adminId) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getAdminNotifications(adminId)));
    }

    @GetMapping("/contact-requests")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<ContactRequestResponse>>> getAllContactRequests(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String priority) {
        return ResponseEntity.ok(ApiResponse.success(contactRequestService.getAllRequests(status, type, priority)));
    }

    @GetMapping("/contact-requests/{id}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<ContactRequestResponse>> getContactRequestById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentAdmin) {
        return ResponseEntity.ok(ApiResponse.success(contactRequestService.getRequestById(id, currentAdmin.getId())));
    }

    @PatchMapping("/contact-requests/{id}/resolve")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<ContactRequestResponse>> resolveContactRequest(
            @PathVariable Integer id,
            @Valid @RequestBody ContactRequestResolveRequest request,
            @AuthenticationPrincipal Account currentAdmin) {
        return ResponseEntity.ok(ApiResponse.success(contactRequestService.resolveRequest(currentAdmin.getId(), id, request)));
    }
}
