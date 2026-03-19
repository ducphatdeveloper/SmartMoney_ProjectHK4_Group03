package fpt.aptech.server.api;

import fpt.aptech.server.dto.notification.NotificationResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
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

    /**
     * Lấy danh sách thông báo của user đang đăng nhập.
     * accId được lấy từ JWT token, không cần truyền qua URL.
     */
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getMyNotifications(
            @AuthenticationPrincipal Account currentUser) {

        // Lấy danh sách Entity từ service
        var notifications = notificationService.getMyNotifications(currentUser.getId());

        // Dùng mapper để chuyển đổi sang danh sách DTO
        List<NotificationResponse> result = notificationMapper.toResponseList(notifications);

        return ResponseEntity.ok(ApiResponse.success(result));
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
