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
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
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
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {

        notificationService.markAsRead(id, currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success("Đã đánh dấu đã đọc."));
    }

    // =================================================================================
    // [3] USER/ADMIN — Đánh dấu tất cả thông báo là đã đọc
    // PUT /api/notifications/read-all
    // =================================================================================
    @PutMapping("/read-all")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(
            @AuthenticationPrincipal Account currentUser) {

        notificationService.markAllAsRead(currentUser.getId());

        return ResponseEntity.ok(ApiResponse.success("Đã đánh dấu tất cả là đã đọc."));
    }

    // =================================================================================
    // [4] ADMIN — Lấy thông báo SYSTEM (notify_type=4) của Admin đang login
    // GET /api/notifications/admin/system
    // Admin web React gọi API này để đổ lên chuông thông báo (bell icon)
    // Bao gồm: cảnh báo giao dịch bất thường, yêu cầu hỗ trợ mới, thông báo hệ thống...
    // =================================================================================
    @GetMapping("/admin/system")
    @PreAuthorize("hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getAdminSystemNotifications(
            @AuthenticationPrincipal Account currentUser) {

        // notify_type = 4 = SYSTEM
        var notifications = notificationService.getMyNotificationsByType(
                currentUser.getId(), NotificationType.SYSTEM.getValue());
        List<NotificationResponse> result = notificationMapper.toResponseList(notifications);

        return ResponseEntity.ok(ApiResponse.success(result));
    }
}
