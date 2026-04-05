package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Integer> {

    // [a] Lấy danh sách thông báo mới nhất của người dùng
    List<Notification> findAllByAccount_IdOrderByScheduledTimeDesc(Integer accId);

    // [b] Lấy danh sách thông báo chưa đọc của người dùng (dùng cho "Đánh dấu tất cả đã đọc")
    List<Notification> findAllByAccount_IdAndNotifyReadIsFalse(Integer accId);

    // [c] Tìm các thông báo chưa gửi để chạy tác vụ ngầm (Scheduler)
    List<Notification> findByNotifySentFalseAndScheduledTimeBefore(java.time.LocalDateTime now);

    // [d] Đếm thông báo chưa đọc (badge chuông)
    long countByAccount_IdAndNotifyReadFalse(Integer accountId);

    // [e] Lấy thông báo theo notifyType (Integer) — sắp xếp mới nhất lên đầu
    List<Notification> findAllByNotifyTypeOrderByScheduledTimeDesc(Integer notifyType);

    // [f] Lấy thông báo của 1 user theo notifyType — dùng cho Admin đọc thông báo SYSTEM (type=4)
    List<Notification> findAllByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(Integer accId, Integer notifyType);
}