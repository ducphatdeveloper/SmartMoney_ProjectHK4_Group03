package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Integer> {

    // [a] Lấy danh sách thông báo mới nhất của người dùng (đã qua scheduledTime)
    @Query("SELECT n FROM Notification n WHERE n.account.id = :accId AND n.scheduledTime <= :now ORDER BY n.scheduledTime DESC")
    List<Notification> findAllVisibleNotificationsByAccount_IdOrderByScheduledTimeDesc(@Param("accId") Integer accId, @Param("now") LocalDateTime now);

    // [b] Lấy danh sách thông báo chưa đọc của người dùng (dùng cho "Đánh dấu tất cả đã đọc")
    List<Notification> findAllByAccount_IdAndNotifyReadIsFalse(Integer accId);

    // [c] Tìm các thông báo chưa gửi để chạy tác vụ ngầm (Scheduler)
    List<Notification> findByNotifySentFalseAndScheduledTimeBefore(LocalDateTime now);

    // [d] Đếm thông báo chưa đọc (badge chuông)
    @Query("SELECT COUNT(n) FROM Notification n WHERE n.account.id = :accountId AND n.notifyRead = false AND n.scheduledTime <= :now")
    long countVisibleUnreadByAccount_Id(@Param("accountId") Integer accountId, @Param("now") LocalDateTime now);

    @Modifying
    @Transactional
    @Query("UPDATE Notification n SET n.notifySent = :sent, n.notifyRead = :read WHERE n.id = :id")
    void updateNotifyStatus(@Param("id") Integer id, @Param("sent") boolean sent, @Param("read") boolean read);

    // [e] Lấy thông báo theo notifyType (Integer) — sắp xếp mới nhất lên đầu (đã qua scheduledTime)
    @Query("SELECT n FROM Notification n WHERE n.notifyType = :notifyType AND n.scheduledTime <= :now ORDER BY n.scheduledTime DESC")
    List<Notification> findAllVisibleNotificationsByNotifyTypeOrderByScheduledTimeDesc(@Param("notifyType") Integer notifyType, @Param("now") LocalDateTime now);

    // [f] Lấy thông báo của 1 user theo notifyType — dùng cho Admin đọc thông báo SYSTEM (type=4) (đã qua scheduledTime)
    @Query("SELECT n FROM Notification n WHERE n.account.id = :accId AND n.notifyType = :notifyType AND n.scheduledTime <= :now ORDER BY n.scheduledTime DESC")
    List<Notification> findAllVisibleNotificationsByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(@Param("accId") Integer accId, @Param("notifyType") Integer notifyType, @Param("now") LocalDateTime now);

    @Deprecated
    List<Notification> findAllByAccount_IdOrderByScheduledTimeDesc(Integer accId);
    @Deprecated
    List<Notification> findAllByNotifyTypeOrderByScheduledTimeDesc(Integer notifyType);
    @Deprecated
    List<Notification> findAllByAccount_IdAndNotifyTypeOrderByScheduledTimeDesc(Integer accId, Integer notifyType);
}