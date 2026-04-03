package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Budget;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface BudgetRepository extends JpaRepository<Budget, Integer> {

    // =================================================================================
    // 1. DANH SÁCH NGÂN SÁCH CỦA USER
    // =================================================================================

    /// [ACTIVE] Ngân sách đang hoạt động (endDate >= today)
    @Query("""
            SELECT b FROM Budget b
            WHERE b.account.id = :accountId
            AND b.wallet.id = :walletId
            AND b.endDate >= :today
            ORDER BY b.beginDate DESC
            """)
    List<Budget> findActiveBudgetsByAccountId(
            Integer accountId,
            Integer walletId,
            LocalDate today);
    /// [EXPIRED] Ngân sách đã kết thúc (endDate < today)
    @Query("SELECT b FROM Budget b WHERE b.account.id = :accountId AND b.endDate < :today ORDER BY b.endDate DESC")
    List<Budget> findExpiredBudgetsByAccountId(@Param("accountId") Integer accountId, @Param("today") LocalDate today);

    // =================================================================================
    // 2. OWNERSHIP CHECK
    // =================================================================================

    Optional<Budget> findByIdAndAccount_Id(Integer id, Integer accountId);

    // =================================================================================
    // 3. CHO SCHEDULER
    // =================================================================================

    /// Tìm tất cả budgets đang active để check notification hàng ngày
    @Query("SELECT b FROM Budget b WHERE :today BETWEEN b.beginDate AND b.endDate")
    List<Budget> findActiveBudgets(@Param("today") LocalDate today);

    /// Tìm budgets cần renew: repeating=true và đã hết hạn (endDate < today)
    @Query("SELECT b FROM Budget b WHERE b.repeating = true AND b.endDate < :today")
    List<Budget> findExpiredRepeatingBudgets(@Param("today") LocalDate today);
    // ADMIN: Tìm tất cả budget có hiệu lực trong khoảng thời gian (để check quá hạn mức)
    @Query("SELECT b FROM Budget b WHERE b.beginDate <= :endDate AND b.endDate >= :startDate")
    List<Budget> findAllActiveBudgetsInRange(@Param("startDate") LocalDate startDate,
                                             @Param("endDate") LocalDate endDate);

    @Query("""
SELECT b FROM Budget b
WHERE b.account.id = :accId
AND b.endDate >= :now
AND (:walletId IS NULL OR b.wallet.id = :walletId)
ORDER BY b.beginDate DESC
""")
    List<Budget> getBudgets(Long accId, LocalDate now, Long walletId);

    @Query("""
SELECT b FROM Budget b
WHERE b.account.id = :accountId
AND (:excludeId IS NULL OR b.id <> :excludeId)

/* Wallet match */
AND b.wallet.id = :walletId

/* Time overlap */
AND b.beginDate <= :endDate
AND b.endDate >= :beginDate
""")
    List<Budget> findConflictingBudgets(
            @Param("accountId") Integer accountId,
            @Param("walletId") Integer walletId,
            @Param("beginDate") LocalDate beginDate,
            @Param("endDate") LocalDate endDate,
            @Param("excludeId") Integer excludeId
    );

    // ── SOFT DELETE CASCADE ─────────────────────────────────────────────

    /// [WALLET] Xóa mềm tất cả Budget thuộc một ví (cascade từ Wallet soft delete)
    @Modifying
    @Query("UPDATE Budget b SET b.deleted = true, b.deletedAt = CURRENT_TIMESTAMP WHERE b.wallet.id = :walletId")
    void softDeleteAllByWalletId(@Param("walletId") Integer walletId);
}