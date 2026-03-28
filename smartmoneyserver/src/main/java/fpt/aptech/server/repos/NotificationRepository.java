package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Notification;
import fpt.aptech.server.enums.notification.NotificationType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Integer> {
    // Lấy danh sách thông báo mới nhất của người dùng
    List<Notification> findAllByAccount_IdOrderByScheduledTimeDesc(Integer accId);

    // Lấy danh sách thông báo chưa đọc của người dùng (dùng cho chức năng "Đánh dấu tất cả là đã đọc")
    List<Notification> findAllByAccount_IdAndNotifyReadIsFalse(Integer accId);

    // Tìm các thông báo chưa gửi để chạy tác vụ ngầm (Scheduler)
    List<Notification> findByNotifySentFalseAndScheduledTimeBefore(java.time.LocalDateTime now);

    // Nếu sau này cần đếm thông báo chưa đọc:
    long countByAccount_IdAndNotifyReadFalse(Integer accountId);

    // Lấy danh sách thông báo theo loại notifyType và sắp xếp mới nhất lên đầu
    List<Notification> findAllByNotifyTypeOrderByScheduledTimeDesc(NotificationType notifyType);
}