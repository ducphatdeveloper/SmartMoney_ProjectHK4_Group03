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

    // Lấy thiết bị của danh sách tài khoản (Dùng cho Batch Fetching ở Dashboard)
    List<UserDevice> findAllByAccount_IdIn(List<Integer> accountIds);

    // Kiểm tra xem user có ít nhất một thiết bị đang ở trạng thái logged_in = 1 hay không
    @Query("SELECT COUNT(d) > 0 FROM UserDevice d WHERE d.account.id = :accountId AND d.loggedIn = true")
    boolean isUserOnline(@Param("accountId") Integer accountId);

    // Lấy các thiết bị đang online của danh sách User (Dựa trên logged_in = 1)
    // Giúp tối ưu dữ liệu khi hiển thị danh sách người dùng ở Dashboard
    @Query("SELECT d FROM UserDevice d WHERE d.account.id IN :accountIds AND d.loggedIn = true")
    List<UserDevice> findLoggedInDevicesByAccountIds(@Param("accountIds") List<Integer> accountIds);

    // Fix lỗi: Thêm phương thức tìm thiết bị active dựa trên trạng thái logged_in và thời gian
    @Query("SELECT d FROM UserDevice d JOIN FETCH d.account WHERE d.loggedIn = true AND (:since IS NULL OR d.lastActive > :since)")
    List<UserDevice> findActiveDevicesBySince(@Param("since") LocalDateTime since);

    // TỐI ƯU: Lấy tất cả thiết bị đang đăng nhập kèm theo thông tin Account (JOIN FETCH)
    // Giải quyết bài toán N+1 cho Live View mà không cần thay đổi Entity Account
    @Query("SELECT d FROM UserDevice d JOIN FETCH d.account WHERE d.loggedIn = true")
    List<UserDevice> findAllLoggedInDevicesWithAccount();

    // Đếm số thiết bị đang hoạt động thực tế trên toàn hệ thống
    long countByRefreshTokenIsNotNull();

    // Khắc phục lỗi: Đếm số lượng thiết bị có trạng thái loggedIn là true
    long countByLoggedInTrue();

    // Đếm tổng số NGƯỜI DÙNG duy nhất đang trực tuyến (Dựa trên trạng thái logged_in = 1)
    @Query("SELECT COUNT(DISTINCT d.account.id) FROM UserDevice d WHERE d.loggedIn = true")
    long countTotalOnlineUsers();
}