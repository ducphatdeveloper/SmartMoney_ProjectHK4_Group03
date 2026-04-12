package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public interface AccountRepository extends JpaRepository<Account, Integer>, JpaSpecificationExecutor<Account> {
    // Tìm tài khoản bằng Email (phục vụ Login/JWT)
    Optional<Account> findByAccEmail(String email);
    // Tìm tài khoản bằng Số điện thoại
    Optional<Account> findByAccPhone(String phone);
    // Tìm theo phone HOẶC email (dùng cho login)
    @Query("SELECT a FROM Account a WHERE a.accPhone = :username OR a.accEmail = :username")
    Optional<Account> findByUsernameOrEmail(String username);

    // Kiểm tra tồn tại để đăng ký
    boolean existsByAccEmail(String email);
    // Kiểm tra phone đã tồn tại
    boolean existsByAccPhone(String accPhone);

    // Tìm danh sách tài khoản theo Role Code (VD: Lấy tất cả Admin)
    List<Account> findByRole_RoleCode(String roleCode);

    // Đếm số người online thực tế dựa trên Refresh Token và thời gian hoạt động
    @Query("SELECT COUNT(DISTINCT d.account.id) FROM UserDevice d " +
            "WHERE d.refreshToken IS NOT NULL AND d.lastActive >= :activeLimit")
    long countOnlineUsers(@Param("activeLimit") LocalDateTime activeLimit);

    // Lấy danh sách ID tài khoản đang online (Dùng làm bước đệm cho lọc nâng cao)
    @Query("SELECT DISTINCT d.account.id FROM UserDevice d " +
            "WHERE d.refreshToken IS NOT NULL AND d.lastActive > :since")
    List<Integer> findOnlineAccountIds(@Param("since") LocalDateTime since);

    @Query("SELECT new map(MONTH(a.createdAt) as month, YEAR(a.createdAt) as year, COUNT(a) as count) " +
            "FROM Account a " +
            "GROUP BY YEAR(a.createdAt), MONTH(a.createdAt) " +
            "ORDER BY YEAR(a.createdAt) DESC, MONTH(a.createdAt) DESC")
    List<Map<String, Object>> countNewUsersByMonth();

    // Tìm kiếm phân trang với filter Locked và Online
    @Query("SELECT DISTINCT a FROM Account a " +
           "LEFT JOIN UserDevice d ON d.account.id = a.id " +
           "WHERE (:search IS NULL OR a.accEmail LIKE %:search% OR a.accPhone LIKE %:search%) " +
           "AND (:locked IS NULL OR a.locked = :locked) " +
           "AND (:online IS NULL OR (:online = true AND d.refreshToken IS NOT NULL AND d.lastActive >= :activeLimit) " +
           "OR (:online = false AND (d.refreshToken IS NULL OR d.lastActive < :activeLimit)))")
    Page<Account> findUsersWithFilters(@Param("search") String search, @Param("locked") Boolean locked, 
                                       @Param("online") Boolean online, @Param("activeLimit") LocalDateTime activeLimit, Pageable pageable);

    /// [SCHEDULER] Lấy tất cả tài khoản active (chưa bị khóa) — dùng cho ReminderScheduler
    @Query("SELECT a FROM Account a WHERE a.locked = false")
    List<Account> findAllActiveAccounts();
}
