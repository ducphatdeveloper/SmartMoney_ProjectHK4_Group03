package fpt.aptech.server.service.notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;

import java.time.LocalDateTime;
import java.util.List;

public interface NotificationService {
    List<Notification> getMyNotifications(Integer accId);
    void markAsSent(Integer notificationId);
    void markAsRead(Integer notificationId, Integer accId); // Sửa userId thành accId
    void markAllAsRead(Integer accId);
    void createNotification(Account account, String title, String content, NotificationType type, Long relatedId, LocalDateTime scheduledTime);
    List<Notification> getNotificationsByType(NotificationType type);
}