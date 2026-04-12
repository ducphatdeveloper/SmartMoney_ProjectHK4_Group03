package fpt.aptech.server.service.notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy thông báo với ID: " + notificationId));

        if (!notification.getAccount().getId().equals(accId)) {
            throw new SecurityException("Bạn không có quyền đánh dấu đã đọc cho thông báo này.");
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
     * Tạo một thông báo mới.
     * ✅ SỬA LỖI Rollback: Sử dụng REQUIRES_NEW để việc tạo thông báo và gửi Push chạy trong 1 Transaction riêng biệt.
     * Nếu gửi Push lỗi, nó sẽ chỉ rollback transaction của chính nó, không ảnh hưởng đến transaction chính (Khôi phục giao dịch).
     */
    @Override
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
                pushNotificationService.sendToUser(account.getId(), title, content);
                notification.setNotifySent(true);
                notificationRepository.save(notification);
            } catch (Exception e) {
                log.error("Gửi Push Notification thất bại cho user {}: {}", account.getId(), e.getMessage());
                // Không ném ngoại lệ ra ngoài để tránh làm hỏng transaction gọi nó
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
                .orElseThrow(() -> new RuntimeException("Không tìm thấy thông báo"));

        if (!notification.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("Bạn không có quyền xóa thông báo này");
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
