package fpt.aptech.server.api;

import fpt.aptech.server.dto.notification.NotificationResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.mapper.notification.NotificationMapper;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationMapper notificationMapper;

    // =================================================================================
    // [1] USER/ADMIN — Lấy danh sách thông báo của account đang login
    // GET /api/notifications
    // =================================================================================
    @GetMapping
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getMyNotifications(
            @AuthenticationPrincipal Account currentUser) {

        var notifications = notificationService.getMyNotifications(currentUser.getId());
        List<NotificationResponse> result = notificationMapper.toResponseList(notifications);

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    // =================================================================================
    // [2] USER/ADMIN — Đánh dấu một thông báo đã đọc
    // PUT /api/notifications/{id}/read
    // =================================================================================
    @PutMapping("/{id}/read")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        notificationService.markAsRead(id, currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success("Marked as read."));
    }

    // =================================================================================
    // [3] USER/ADMIN — Đánh dấu tất cả thông báo là đã đọc
    // PUT /api/notifications/read-all
    // =================================================================================
    @PutMapping("/read-all")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(
            @AuthenticationPrincipal Account currentUser) {

        notificationService.markAllAsRead(currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success("All marked as read."));
    }

    // =================================================================================
    // [4] ADMIN — Lấy thông báo SYSTEM (notify_type=4) của Admin đang login
    // Admin web React gọi API này để đổ lên chuông thông báo (bell icon)
    // Bao gồm: cảnh báo giao dịch bất thường, yêu cầu hỗ trợ mới, thông báo hệ thống...
    // =================================================================================
    @GetMapping("/admin/system")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getAdminSystemNotifications(
            @AuthenticationPrincipal Account currentUser) {

        // notify_type = 4 = SYSTEM
        var notifications = notificationService.getMyNotificationsByType(
                currentUser.getId(), NotificationType.SYSTEM.getValue());
        List<NotificationResponse> result = notificationMapper.toResponseList(notifications);

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    // =================================================================================
    // [5] USER/ADMIN — Xóa một thông báo
    // DELETE /api/notifications/{id}
    // =================================================================================
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> deleteNotification(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        notificationService.deleteNotification(id, currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success("Notification deleted successfully."));
    }
    // =================================================================================
    // [6] MOBILE — Gọi khi điện thoại nhận được thông báo từ FCM (Background/Foreground)
    // PATCH /api/notifications/{id}/delivered
    // =================================================================================
    @PatchMapping("/{id}/delivered")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> markAsDelivered(@PathVariable Integer id) {
        notificationService.markAsDelivered(id);
        return ResponseEntity.ok(ApiResponse.success("Notification delivery confirmed."));
    }
}
