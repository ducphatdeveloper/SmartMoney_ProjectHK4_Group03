package fpt.aptech.server.service.notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async; // Import Async
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImp implements NotificationService {

    private final NotificationRepository notificationRepository;
    private final IPushNotificationService pushNotificationService;

    @Override
    public List<Notification> getMyNotifications(Integer accId) {
        return notificationRepository.findAllVisibleNotificationsByAccount_IdOrderByScheduledTimeDesc(accId, LocalDateTime.now());
    }

    @Override
    @Transactional
    public void markAsSent(Integer notificationId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            n.setNotifySent(true);
            notificationRepository.save(n);
        });
    }

    @Override
    @Transactional
    public void markAsRead(Integer notificationId, Integer accId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalArgumentException("Notification not found with ID: " + notificationId));

        if (!notification.getAccount().getId().equals(accId)) {
            throw new SecurityException("You do not have permission to mark this notification as read.");
        }

        notification.setNotifyRead(true);
        notificationRepository.save(notification);
    }

    @Override
    @Transactional
    public void markAllAsRead(Integer accId) {
        List<Notification> notifications = notificationRepository.findAllByAccount_IdAndNotifyReadIsFalse(accId);
        if (!notifications.isEmpty()) {
            notifications.forEach(n -> n.setNotifyRead(true));
            notificationRepository.saveAll(notifications);
        }
    }

    /**
     * Tạo một thông báo mới (Bất đồng bộ).
     * ✅ TỐI ƯU HIỆU SUẤT: Sử dụng @Async để việc tạo và gửi Push Notification không chặn luồng chính.
     * Admin sẽ nhận được phản hồi ngay lập tức khi xử lý Support Request.
     */
    @Override
    @Async // Chạy bất đồng bộ
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void createNotification(Account account, String title, String content, NotificationType type, Long relatedId, LocalDateTime scheduledTime) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime effectiveScheduledTime = (scheduledTime != null) ? scheduledTime : now;

        Notification notification = Notification.builder()
                .account(account)
                .title(title)
                .content(content)
                .notifyType(type.getValue())
                .relatedId(relatedId)
                .scheduledTime(effectiveScheduledTime)
                .notifySent(false)
                .notifyRead(false)
                .createdAt(now)
                .build();
        notificationRepository.save(notification);

        if (!effectiveScheduledTime.isAfter(now)) {
            try {
                // Gửi Push Notification (Thao tác tốn thời gian nhất)
                pushNotificationService.sendToUser(account.getId(), title, content);
                notification.setNotifySent(true);
                notificationRepository.save(notification);
            } catch (Exception e) {
                log.error("Gửi Push Notification thất bại cho user {}: {}", account.getId(), e.getMessage());
            }
        }
    }

    @Override
    public List<Notification> getNotificationsByType(Integer notifyType) {
        return notificationRepository.findAllVisibleNotificationsByNotifyTypeOrderByScheduledTimeDesc(notifyType, LocalDateTime.now());
    }

    @Override
    public List<Notification> getMyNotificationsByType(Integer accId, Integer notifyType) {
        return notificationRepository.findAllVisibleNotificationsByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(accId, notifyType, LocalDateTime.now());
    }

    @Override
    @Transactional
    public void deleteNotification(Integer id, Integer accountId) {
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Notification not found"));

        if (!notification.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("You do not have permission to delete this notification");
        }

        notificationRepository.delete(notification);
        notificationRepository.flush();
    }

    @Override
    @Transactional
    public void markAsDelivered(Integer id) {
        notificationRepository.updateNotifyStatus(id, true, true);
    }
}
