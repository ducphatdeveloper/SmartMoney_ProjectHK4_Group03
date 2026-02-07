package fpt.aptech.server.service.Notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;

import java.util.List;

public interface NotificationService {
    List<Notification> getMyNotifications(Integer accId);
    void markAsSent(Integer notificationId);
    void markAsRead(Integer notificationId);
    void markAllAsRead(Integer accId);
    void createNotification(Account account, String title, String content, Integer type, Long relatedId);
}
