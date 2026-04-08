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
     * Lấy danh sách thông báo của một người dùng mà scheduledTime <= hiện tại.
     * Ẩn các thông báo ở tương lai cho đến khi đến hạn.
     */
    @Override
    public List<Notification> getMyNotifications(Integer accId) {
        return notificationRepository.findAllVisibleNotificationsByAccount_IdOrderByScheduledTimeDesc(accId, LocalDateTime.now());
    }

    /**
     * Đánh dấu một thông báo là "đã gửi" (push notification).
     * Thường được gọi bởi một worker hoặc scheduler sau khi gửi push thành công.
     */
    @Override
    @Transactional
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
    @Transactional
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
     * Tạo một thông báo mới trong hệ thống.
     * Nếu scheduledTime <= hiện tại hoặc null, gửi push ngay lập tức.
     * Ngược lại, chỉ lưu vào DB để Scheduler quét gửi sau.
     */
    @Override
    @Transactional
    public void createNotification(Account account, String title, String content, NotificationType type, Long relatedId, LocalDateTime scheduledTime) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime effectiveScheduledTime = (scheduledTime != null) ? scheduledTime : now;

        // Bước 1: Tạo và lưu thông báo vào database
        Notification notification = Notification.builder()
                .account(account)
                .title(title)
                .content(content)
                .notifyType(type.getValue())
                .relatedId(relatedId)
                .scheduledTime(effectiveScheduledTime)
                .notifySent(false) // Mặc định là chưa gửi
                .notifyRead(false) // Mặc định là chưa đọc
                .createdAt(now)
                .build();
        notificationRepository.save(notification);

        // Bước 2: Nếu scheduledTime đến hạn ngay bây giờ, kích hoạt gửi push ngay
        if (!effectiveScheduledTime.isAfter(now)) {
            try {
                pushNotificationService.sendToUser(account.getId(), title, content);
                // Cập nhật notify_sent = true sau khi Firebase đã nhận yêu cầu gửi thành công.
                notification.setNotifySent(true);
                notificationRepository.save(notification);
            } catch (Exception e) {
                // Log lỗi nhưng không rollback vì thông báo đã được lưu trong DB để Scheduler thử lại sau
            }
        }
    }

    @Override
    public List<Notification> getNotificationsByType(Integer notifyType) {
        // Gọi repository để lấy thông báo theo notifyType (Integer) và sắp xếp mới nhất lên đầu
        // Chỉ lấy các thông báo đã đến hạn scheduledTime
        return notificationRepository.findAllVisibleNotificationsByNotifyTypeOrderByScheduledTimeDesc(notifyType, LocalDateTime.now());
    }

    /**
     * Lấy thông báo của 1 user theo notifyType.
     * Admin dùng để đọc thông báo SYSTEM (type=4) của chính mình.
     * Ẩn các thông báo ở tương lai cho đến khi đến hạn.
     */
    @Override
    public List<Notification> getMyNotificationsByType(Integer accId, Integer notifyType) {
        return notificationRepository.findAllVisibleNotificationsByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(accId, notifyType, LocalDateTime.now());
    }

    /**
     * Xóa thông báo khỏi database.
     * Đảm bảo bản ghi được gỡ bỏ hoàn toàn khỏi DB.
     */
    @Override
    @Transactional
    public void deleteNotification(Integer id, Integer accountId) {
        // Kiểm tra tồn tại và quyền sở hữu trước khi xóa
        Notification notification = notificationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy thông báo"));

        if (!notification.getAccount().getId().equals(accountId)) {
            throw new RuntimeException("Bạn không có quyền xóa thông báo này");
        }

        notificationRepository.delete(notification);
        // Force flush để đảm bảo xóa khỏi DB ngay lập tức
        notificationRepository.flush();
    }
    @Override
    @Transactional
    public void markAsDelivered(Integer id) {
        notificationRepository.updateNotifyStatus(id, true, true); // sent=true, read=true
    }
}