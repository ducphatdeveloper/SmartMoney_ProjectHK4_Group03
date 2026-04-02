package fpt.aptech.server.api;

import fpt.aptech.server.dto.notification.NotificationResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.mapper.notification.NotificationMapper;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationMapper notificationMapper;

    /**
     * Lấy danh sách thông báo của user đang đăng nhập.
     * Hỗ trợ lọc theo loại thông báo và trạng thái chưa đọc.
     */
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getMyNotifications(
            @AuthenticationPrincipal Account currentUser,
            @RequestParam(required = false) NotificationType type,
            @RequestParam(required = false) Boolean unreadOnly) {

        var notifications = notificationService.getMyNotifications(currentUser.getId());

        // Logic lọc tại controller để giảm tải cho Service/Repository nếu danh sách không quá lớn
        var stream = notifications.stream();
        
        if (type != null) {
            stream = stream.filter(n -> n.getNotifyType() == type.getValue());
        }
        
        if (Boolean.TRUE.equals(unreadOnly)) {
            stream = stream.filter(n -> Boolean.FALSE.equals(n.getNotifyRead()));
        }

        List<NotificationResponse> result = notificationMapper.toResponseList(
                stream.sorted(Comparator.comparing(Notification::getScheduledTime).reversed())
                      .collect(Collectors.toList())
        );

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /**
     * Lấy số lượng thông báo chưa đọc.
     * Dùng để hiển thị số icon badge trên Mobile/Web.
     */
    @GetMapping("/unread-count")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Long>> getUnreadCount(
            @AuthenticationPrincipal Account currentUser) {
        
        long count = notificationService.getMyNotifications(currentUser.getId())
                .stream()
                .filter(n -> Boolean.FALSE.equals(n.getNotifyRead()))
                .count();
                
        return ResponseEntity.ok(ApiResponse.success(count));
    }

    /**
     * Đánh dấu một thông báo đã đọc.
     * Service sẽ kiểm tra quyền sở hữu trước khi thực hiện.
     */
    @PutMapping("/{id}/read")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        // Truyền cả ID thông báo và ID của user xuống service để check quyền
        notificationService.markAsRead(id, currentUser.getId());
        
        return ResponseEntity.ok(ApiResponse.success("Đã đánh dấu đã đọc."));
    }

    /**
     * Đánh dấu tất cả thông báo là đã đọc.
     */
    @PutMapping("/read-all")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(
            @AuthenticationPrincipal Account currentUser) {
        
        notificationService.markAllAsRead(currentUser.getId());
        
        return ResponseEntity.ok(ApiResponse.success("Đã đánh dấu tất cả là đã đọc."));
    }
}
