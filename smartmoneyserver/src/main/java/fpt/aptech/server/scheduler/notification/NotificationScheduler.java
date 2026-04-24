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

/**
 * Scheduler gửi thông báo đã lên lịch (scheduledTime).
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — processScheduledNotifications(): Mỗi phút → Gửi thông báo đến hạn scheduledTime
 * ────────────────────────────────────────────────────────────────────────
 * Lý do mỗi phút: Kiểm tra liên tục để gửi thông báo ngay khi đến hạn scheduledTime.
 *
 * Thông báo được tạo ra:
 *   Không tạo thông báo mới, chỉ gửi thông báo đã được tạo bởi các scheduler khác
 *   khi scheduledTime đến hạn và notifySent = false.
 *
 * Bảo mật: Mỗi thông báo gắn account → chỉ đúng user nhận được.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationScheduler {

    private final NotificationRepository notificationRepository;
    private final IPushNotificationService pushNotificationService;

    /**
     * Chạy mỗi phút để kiểm tra các thông báo đến hạn scheduledTime và chưa gửi (notifySent = false).
     */
    @Scheduled(cron = "0 */2 * * * *")
    @Transactional
    public void processScheduledNotifications() {
        LocalDateTime now = LocalDateTime.now();
        List<Notification> pendingNotifications = notificationRepository.findByNotifySentFalseAndScheduledTimeBefore(now);

        if (pendingNotifications.isEmpty()) {
            return;
        }

        // log.info("[NotificationScheduler] Found {} notifications due for sending.", pendingNotifications.size());

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

                // log.info("[NotificationScheduler] Sent notification ID: {} to User ID: {}",
                //         notification.getId(), notification.getAccount().getId());
            } catch (Exception e) {
                // log.error("[NotificationScheduler] Error sending notification ID: {}: {}",
                //         notification.getId(), e.getMessage());
            }
        }
    }
}
