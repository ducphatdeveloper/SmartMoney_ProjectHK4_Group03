package fpt.aptech.server.service.Notification;

import fpt.aptech.server.entity.Notification;

import java.util.List;

public interface NotificationService {
    List<Notification> getMyNotifications(Integer accId);
    void markAsSent(Integer notificationId);
}
