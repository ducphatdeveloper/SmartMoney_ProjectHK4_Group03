package fpt.aptech.server.repos;

import fpt.aptech.server.entity.PlannedTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface PlannedTransactionRepository extends JpaRepository<PlannedTransaction, Integer> {

    // ── CRUD ────────────────────────────────────────────────────────────

    // Lấy theo plan_type + active (dùng cho cả 2 menu)
    List<PlannedTransaction> findByAccount_IdAndPlanTypeAndActiveOrderByCreatedAtDesc(
            Integer accId, Integer planType, Boolean active);

    // Lấy 1 planned theo id (kiểm tra ownership ở Service)
    Optional<PlannedTransaction> findByIdAndAccount_Id(Integer id, Integer accId);

    @Modifying
    @Query("UPDATE PlannedTransaction p SET p.debt = null WHERE p.debt.id = :debtId")
    void setDebtIdToNullByDebtId(@Param("debtId") Integer debtId);

    // ── SCHEDULER ───────────────────────────────────────────────────────

    // Chỉ lấy Recurring (plan_type=2) đến hạn → tự tạo Transaction
    // JOIN FETCH category + wallet + account + debt để tránh LazyInitializationException trong @Transactional(REQUIRES_NEW)
    // LEFT JOIN FETCH debt vì debt_id có thể NULL (không phải mọi recurring đều liên kết nợ)
    @Query("""
        SELECT p FROM PlannedTransaction p
        JOIN FETCH p.category
        JOIN FETCH p.wallet
        JOIN FETCH p.account
        LEFT JOIN FETCH p.debt
        WHERE p.active = true
          AND p.planType = 2
          AND p.nextDueDate <= :today
        ORDER BY p.nextDueDate ASC
    """)
    List<PlannedTransaction> findRecurringDueToday(@Param("today") LocalDate today);

    // Chỉ lấy Bills (plan_type=1) đến hạn → gửi notification nhắc
    // JOIN FETCH category + wallet + account + debt để tránh LazyInitializationException trong @Transactional(REQUIRES_NEW)
    // LEFT JOIN FETCH debt vì debt_id có thể NULL
    @Query("""
        SELECT p FROM PlannedTransaction p
        JOIN FETCH p.category
        JOIN FETCH p.wallet
        JOIN FETCH p.account
        LEFT JOIN FETCH p.debt
        WHERE p.active = true
          AND p.planType = 1
          AND p.nextDueDate <= :today
        ORDER BY p.nextDueDate ASC
    """)
    List<PlannedTransaction> findBillsDueToday(@Param("today") LocalDate today);

    // ── DEBT INTEGRATION ────────────────────────────────────────────────

    // Khi trả hết nợ → tắt tất cả planned liên kết debt đó
    @Modifying
    @Query("""
        UPDATE PlannedTransaction p
        SET p.active = false
        WHERE p.debt.id = :debtId
    """)
    void deactivateAllByDebtId(@Param("debtId") Integer debtId);

    // ── SOFT DELETE CASCADE ─────────────────────────────────────────────

    /// [WALLET] Xóa mềm tất cả PlannedTransaction thuộc một ví (cascade từ Wallet soft delete)
    @Modifying
    @Query("UPDATE PlannedTransaction p SET p.deleted = true, p.deletedAt = CURRENT_TIMESTAMP WHERE p.wallet.id = :walletId")
    void softDeleteAllByWalletId(@Param("walletId") Integer walletId);
}
