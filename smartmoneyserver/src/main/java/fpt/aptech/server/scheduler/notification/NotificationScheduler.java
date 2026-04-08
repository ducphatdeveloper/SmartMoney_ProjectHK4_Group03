package fpt.aptech.server.scheduler.notification;

import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.repos.NotificationRepository;
import fpt.aptech.server.service.notification.IPushNotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationScheduler {

    private final NotificationRepository notificationRepository;
    private final IPushNotificationService pushNotificationService;

    /**
     * Chạy mỗi phút để kiểm tra các thông báo đến hạn scheduledTime và chưa gửi (notifySent = false).
     */
    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void processScheduledNotifications() {
        LocalDateTime now = LocalDateTime.now();
        List<Notification> pendingNotifications = notificationRepository.findByNotifySentFalseAndScheduledTimeBefore(now);

        if (pendingNotifications.isEmpty()) {
            return;
        }

        log.info("[NotificationScheduler] Tìm thấy {} thông báo đến hạn gửi.", pendingNotifications.size());

        for (Notification notification : pendingNotifications) {
            try {
                // Gửi push notification qua Firebase
                pushNotificationService.sendToUser(
                        notification.getAccount().getId(),
                        notification.getTitle(),
                        notification.getContent()
                );

                // Đánh dấu đã gửi
                notification.setNotifySent(true);
                notificationRepository.save(notification);

                log.info("[NotificationScheduler] Đã gửi thông báo ID: {} cho User ID: {}", 
                        notification.getId(), notification.getAccount().getId());
            } catch (Exception e) {
                log.error("[NotificationScheduler] Lỗi khi gửi thông báo ID: {}: {}", 
                        notification.getId(), e.getMessage());
            }
        }
    }
}
