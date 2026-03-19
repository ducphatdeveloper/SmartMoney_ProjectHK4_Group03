package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Budget;
import org.springframework.data.jpa.repository.JpaRepository;
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
    @Query("SELECT b FROM Budget b WHERE b.account.id = :accountId AND b.endDate >= :today ORDER BY b.beginDate DESC")
    List<Budget> findActiveBudgetsByAccountId(@Param("accountId") Integer accountId, @Param("today") LocalDate today);

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
}