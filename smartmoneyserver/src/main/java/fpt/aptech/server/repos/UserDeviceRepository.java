package fpt.aptech.server.repos;

import fpt.aptech.server.entity.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    // Tìm tất cả thiết bị của một tài khoản (Dùng để thu hồi token khi khóa tài khoản)
    List<UserDevice> findAllByAccount_Id(Integer accountId);

    // Kiểm tra trạng thái Online thời gian thực (loggedIn = 1 AND lastActive > mốc thời gian)
    @Query("SELECT COUNT(d) > 0 FROM UserDevice d WHERE d.account.id = :accountId AND d.loggedIn = true AND d.lastActive > :since")
    boolean isUserOnline(@Param("accountId") Integer accountId, @Param("since") LocalDateTime since);

    // Lấy danh sách thiết bị active của các User (Fix lỗi: findActiveDevicesByAccountIds)
    @Query("SELECT d FROM UserDevice d WHERE d.account.id IN :accountIds AND d.loggedIn = true AND d.lastActive > :since")
    List<UserDevice> findActiveDevicesByAccountIds(@Param("accountIds") List<Integer> accountIds, @Param("since") LocalDateTime since);

    // Tìm thiết bị active cho mục đích Live View hoặc Auto Logout
    @Query("SELECT d FROM UserDevice d JOIN FETCH d.account WHERE d.loggedIn = true AND (:since IS NULL OR d.lastActive > :since)")
    List<UserDevice> findActiveDevicesBySince(@Param("since") LocalDateTime since);

    // Đếm tổng số NGƯỜI DÙNG duy nhất đang trực tuyến thực tế (Fix lỗi: countActiveUsers)
    @Query("SELECT COUNT(DISTINCT d.account.id) FROM UserDevice d WHERE d.loggedIn = true AND d.lastActive > :since")
    long countActiveUsers(@Param("since") LocalDateTime since);


    // TỐI ƯU: Lấy tất cả thiết bị đang đăng nhập kèm theo thông tin Account (JOIN FETCH)
    // Giải quyết bài toán N+1 cho Live View mà không cần thay đổi Entity Account
    @Query("SELECT d FROM UserDevice d JOIN FETCH d.account WHERE d.loggedIn = true")
    List<UserDevice> findAllLoggedInDevicesWithAccount();


    // Khắc phục lỗi: Đếm số lượng thiết bị có trạng thái loggedIn là true
    long countByLoggedInTrue();


}