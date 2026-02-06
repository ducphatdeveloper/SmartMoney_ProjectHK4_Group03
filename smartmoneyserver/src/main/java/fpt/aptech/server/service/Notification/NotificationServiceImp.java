package fpt.aptech.server.service.Notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.repos.NotificationRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class NotificationServiceImp implements NotificationService {
    @Autowired
    private NotificationRepository notificationRepository;

    @Override
    public List<Notification> getMyNotifications(Integer accId) {
        return notificationRepository.findAllByAccount_IdOrderByScheduledTimeDesc(accId);
    }

    @Override
    public void markAsSent(Integer notificationId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            n.setNotifySent(true);
            notificationRepository.save(n);
        });
    }

    @Override
    public void markAsRead(Integer notificationId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            n.setNotifyRead(true);
            notificationRepository.save(n);
        });
    }

    @Override
    @Transactional
    public void markAllAsRead(Integer accId) {
        List<Notification> notifications = notificationRepository.findAllByAccount_IdOrderByScheduledTimeDesc(accId);
        notifications.forEach(n -> n.setNotifyRead(true));
        notificationRepository.saveAll(notifications);
    }

    @Override
    public void createNotification(Account account, String title, String content, Integer type, Long relatedId) {
        Notification notification = Notification.builder()
                .account(account)
                .title(title)
                .content(content)
                .notifyType(type)
                .relatedId(relatedId)
                .scheduledTime(LocalDateTime.now())
                .notifySent(false)
                .notifyRead(false)
                .createdAt(LocalDateTime.now())
                .build();
        notificationRepository.save(notification);
    }
}
