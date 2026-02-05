package fpt.aptech.server.repos;

import fpt.aptech.server.entity.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserDeviceRepository extends JpaRepository<UserDevice, Integer> {
    // Tìm thiết bị theo token
    Optional<UserDevice> findByDeviceToken(String deviceToken);

    // Tìm tất cả thiết bị đang đăng nhập (loggedIn = true) của một tài khoản
    List<UserDevice> findAllByAccount_IdAndLoggedInTrue(Integer accountId);

    // Đếm tổng số thiết bị đang hoạt động trên toàn hệ thống
    long countByLoggedInTrue();
}
