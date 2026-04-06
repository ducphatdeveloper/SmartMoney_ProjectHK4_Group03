package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Wallet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, Integer> {
    List<Wallet> findByAccountId(Integer accountId);

    List<Wallet> findByAccountIdAndWalletNameContainingIgnoreCase(Integer accountId, String walletName);

    // Tính tổng số dư của tất cả các ví được tính vào báo cáo (reportable = true)
    @Query("SELECT SUM(w.balance) FROM Wallet w WHERE w.account.id = :accountId AND w.reportable = true AND w.deleted = false")
    BigDecimal sumBalanceByAccountIdAndReportableTrue(Integer accountId);

    // Hàm Check trùng ví
    boolean existsByAccountIdAndWalletNameIgnoreCase(Integer accountId, String walletName);
}
