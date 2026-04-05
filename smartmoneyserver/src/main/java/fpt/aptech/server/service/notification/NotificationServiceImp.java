package fpt.aptech.server.service.notification;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationServiceImp implements NotificationService {

    private final NotificationRepository notificationRepository;
    private final IPushNotificationService pushNotificationService; // Inject service gửi push

    /**
     * Lấy danh sách tất cả thông báo của một người dùng, sắp xếp theo thời gian mới nhất.
     */
    @Override
    public List<Notification> getMyNotifications(Integer accId) {
        return notificationRepository.findAllByAccount_IdOrderByScheduledTimeDesc(accId);
    }

    /**
     * Đánh dấu một thông báo là "đã gửi" (push notification).
     * Thường được gọi bởi một worker hoặc scheduler sau khi gửi push thành công.
     */
    @Override
    public void markAsSent(Integer notificationId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            n.setNotifySent(true);
            notificationRepository.save(n);
        });
    }

    /**
     * Đánh dấu một thông báo là "đã đọc" bởi người dùng.
     */
    @Override
    public void markAsRead(Integer notificationId, Integer accId) {
        // Tìm thông báo theo ID
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy thông báo với ID: " + notificationId));

        // Kiểm tra quyền sở hữu
        if (!notification.getAccount().getId().equals(accId)) {
            throw new SecurityException("Bạn không có quyền đánh dấu đã đọc cho thông báo này.");
        }

        // Cập nhật trạng thái và lưu lại
        notification.setNotifyRead(true);
        notificationRepository.save(notification);
    }

    /**
     * Đánh dấu tất cả thông báo của người dùng là "đã đọc".
     */
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
     * Tạo một thông báo mới trong hệ thống và kích hoạt gửi push notification.
     */
    @Override
    @Transactional
    public void createNotification(Account account, String title, String content, NotificationType type, Long relatedId, LocalDateTime scheduledTime) {
        // Bước 1: Tạo và lưu thông báo vào database
        Notification notification = Notification.builder()
                .account(account)
                .title(title)
                .content(content)
                .notifyType(type.getValue())
                .relatedId(relatedId)
                .scheduledTime(scheduledTime != null ? scheduledTime : LocalDateTime.now())
                .notifySent(false) // Mặc định là chưa gửi
                .notifyRead(false) // Mặc định là chưa đọc
                .createdAt(LocalDateTime.now())
                .build();
        notificationRepository.save(notification);

        // Bước 2: Nếu là thông báo gửi ngay (không hẹn lịch), kích hoạt gửi push
        if (scheduledTime == null) {
            pushNotificationService.sendToUser(account.getId(), title, content);
            // Bước 3: Cập nhật trạng thái đã gửi.
            // Cập nhật notify_sent = true sau khi Firebase đã nhận yêu cầu gửi thành công.
            notification.setNotifySent(true);
            notificationRepository.save(notification);
        }
    }

    @Override
    public List<Notification> getNotificationsByType(Integer notifyType) {
        // Gọi repository để lấy thông báo theo notifyType (Integer) và sắp xếp mới nhất lên đầu
        return notificationRepository.findAllByNotifyTypeOrderByScheduledTimeDesc(notifyType);
    }

    /**
     * Lấy thông báo của 1 user theo notifyType.
     * Admin dùng để đọc thông báo SYSTEM (type=4) của chính mình.
     */
    @Override
    public List<Notification> getMyNotificationsByType(Integer accId, Integer notifyType) {
        return notificationRepository.findAllByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(accId, notifyType);
    }
}