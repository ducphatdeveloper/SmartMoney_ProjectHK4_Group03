package fpt.aptech.server.api;

import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.service.Notification.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    // Lấy danh sách thông báo của một tài khoản cụ thể
    @GetMapping("/user/{accId}")
    public ResponseEntity<List<Notification>> getUserNotifications(@PathVariable Integer accId) {
        return ResponseEntity.ok(notificationService.getMyNotifications(accId));
    }

    // Đánh dấu một thông báo đã được gửi/đọc
    @PutMapping("/{id}/sent")
    public ResponseEntity<Void> markAsSent(@PathVariable Integer id) {
        notificationService.markAsSent(id);
        return ResponseEntity.ok().build();
    }
}