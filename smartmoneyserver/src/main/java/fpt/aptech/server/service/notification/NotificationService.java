package fpt.aptech.server.service.notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;
import jakarta.transaction.Transactional;

import java.time.LocalDateTime;
import java.util.List;

public interface NotificationService {
    List<Notification> getMyNotifications(Integer accId);
    void markAsSent(Integer notificationId);
    void markAsRead(Integer notificationId, Integer accId);
    void markAllAsRead(Integer accId);

    /**
     * Xóa thông báo khỏi database.
     * @param notificationId ID của thông báo cần xóa
     * @param accId ID của chủ sở hữu để đảm bảo tính bảo mật
     */
    @Transactional
    void deleteNotification(Integer id, Integer accountId);


    void createNotification(Account account, String title, String content, NotificationType type, Long relatedId, LocalDateTime scheduledTime);
    List<Notification> getNotificationsByType(Integer notifyType);

    /**
     * Lấy thông báo của 1 user theo notifyType.
     * Dùng cho Admin đọc thông báo SYSTEM (type=4) của chính mình.
     */
    List<Notification> getMyNotificationsByType(Integer accId, Integer notifyType);
    @Transactional
    void markAsDelivered(Integer id); // Cập nhật khi nhận được thông báo

}