package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public interface AccountRepository extends JpaRepository<Account, Integer> {
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


    @Query("SELECT new map(MONTH(a.createdAt) as month, YEAR(a.createdAt) as year, COUNT(a) as count) " +
            "FROM Account a " +
            "GROUP BY YEAR(a.createdAt), MONTH(a.createdAt) " +
            "ORDER BY YEAR(a.createdAt) DESC, MONTH(a.createdAt) DESC")
    List<Map<String, Object>> countNewUsersByMonth();
}
