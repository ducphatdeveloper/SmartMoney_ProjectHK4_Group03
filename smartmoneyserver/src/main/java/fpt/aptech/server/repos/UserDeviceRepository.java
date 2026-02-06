package fpt.aptech.server.repos;

import fpt.aptech.server.entity.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserDeviceRepository extends JpaRepository<UserDevice, Integer> {
    // Tìm thiết bị theo token (Cũ - dễ gây lỗi nếu dữ liệu không unique)
    Optional<UserDevice> findByDeviceToken(String deviceToken);
    
    // Tìm tất cả thiết bị theo token (Mới - để xử lý trùng lặp)
    List<UserDevice> findAllByDeviceToken(String deviceToken);

    // Tìm tất cả thiết bị đang đăng nhập (loggedIn = true) của một tài khoản
    List<UserDevice> findAllByAccount_IdAndLoggedInTrue(Integer accountId);

    // Tìm tất cả thiết bị của một tài khoản (để force logout khi khóa)
    List<UserDevice> findAllByAccount_Id(Integer accountId);

    // Đếm tổng số thiết bị đang hoạt động trên toàn hệ thống
    long countByLoggedInTrue();

    // Kiểm tra xem user có thiết bị nào đang online không (loggedIn = true VÀ lastActive > 5 phút trước)
    @Query("SELECT COUNT(d) > 0 FROM UserDevice d WHERE d.account.id = :accountId AND d.loggedIn = true AND d.lastActive > :timeThreshold")
    boolean isUserOnline(Integer accountId, LocalDateTime timeThreshold);

    // Lấy thời gian hoạt động gần nhất của user
    @Query("SELECT MAX(d.lastActive) FROM UserDevice d WHERE d.account.id = :accountId")
    LocalDateTime findLatestActiveTime(Integer accountId);
}