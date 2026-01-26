package fpt.aptech.server.repos;

import fpt.aptech.server.entity.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserDeviceRepository extends JpaRepository<UserDevice, Integer> {
    // Tìm thiết bị theo Token (để validate hoặc logout)
    Optional<UserDevice> findByDeviceToken(String deviceToken);

    // Lấy danh sách thiết bị đang đăng nhập của một Account
    List<UserDevice> findAllByAccount_IdAndLoggedInTrue(Integer accId);

    // Tìm thiết bị theo Refresh Token để cấp lại Access Token mới
    Optional<UserDevice> findByRefreshToken(String refreshToken);

    long countByLoggedInTrue();
}
