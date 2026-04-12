package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Debt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface DebtRepository extends JpaRepository<Debt, Integer> {

    /// [VIEW] Lấy tất cả khoản nợ theo loại (cả chưa xong lẫn đã xong)
    /// Dùng cho Tab CẦN TRẢ (debtType=false) và Tab CẦN THU (debtType=true)
    /// Flutter tự chia 2 header: "CHƯA TRẢ" / "ĐÃ TRẢ HẾT" dựa theo field finished
    List<Debt> findAllByAccount_IdAndDebtTypeOrderByCreatedAtDesc(
            Integer accountId, Boolean debtType);

    /// [VALIDATE] Kiểm tra debt có thuộc về user không (dùng trong getOwnedDebt)
    Optional<Debt> findByIdAndAccount_Id(Integer id, Integer accountId);

    // [FIX] Xóa Debt bằng JPQL DELETE trực tiếp (không qua entity lifecycle).
    // Dùng thay cho debtRepository.delete(debt) trong DebtCalculationServiceImpl.recalculateDebt()
    // để tránh TransientObjectException: khi dùng delete(entity), Hibernate đánh dấu entity là REMOVED
    // → các entity khác (Transaction) vẫn giữ reference → flush sẽ báo lỗi.
    // JPQL DELETE không thay đổi trạng thái entity trong 1L cache → an toàn hơn.
    @Modifying
    @Query("DELETE FROM Debt d WHERE d.id = :id")
    void deleteByDebtId(@Param("id") Integer id);

    // ── SOFT DELETE CASCADE ───────────────────────────────────────────────────────────
    // Dùng Native SQL để bỏ qua @SQLRestriction("deleted = 0") trên bảng tTransactions,
    // đảm bảo tìm được khoản nợ ngay cả khi giao dịch liên kết đã bị xóa mềm trước đó.

    /// [CASCADE] Xóa mềm tất cả khoản nợ có giao dịch thuộc một ví (cascade từ Wallet soft delete)
    @Modifying
    @Query(value = "UPDATE tDebts SET deleted = 1, deleted_at = CURRENT_TIMESTAMP " +
                   "WHERE id IN (SELECT DISTINCT debt_id FROM tTransactions " +
                   "             WHERE wallet_id = :walletId AND debt_id IS NOT NULL)",
           nativeQuery = true)
    void softDeleteAllByWalletId(@Param("walletId") Integer walletId);

    /// [CASCADE] Xóa mềm tất cả khoản nợ có giao dịch thuộc một mục tiêu (cascade từ SavingGoal soft delete)
    @Modifying
    @Query(value = "UPDATE tDebts SET deleted = 1, deleted_at = CURRENT_TIMESTAMP " +
                   "WHERE id IN (SELECT DISTINCT debt_id FROM tTransactions " +
                   "             WHERE goal_id = :goalId AND debt_id IS NOT NULL)",
           nativeQuery = true)
    void softDeleteAllBySavingGoalId(@Param("goalId") Integer goalId);

    // ── SCHEDULER QUERIES ───────────────────────────────────────────────────────────

    /// [SCHEDULER] Tìm khoản nợ chưa xong, có due_date nằm trong khoảng [from, to]
    /// Dùng cho DebtScheduler — nhắc khoản nợ sắp đến hạn (today → today+3)
    @Query("SELECT d FROM Debt d WHERE d.finished = false " +
           "AND d.dueDate IS NOT NULL " +
           "AND d.dueDate >= :from AND d.dueDate < :to")
    List<Debt> findActiveDebtsWithDueDateBetween(@Param("from") LocalDateTime from,
                                                  @Param("to") LocalDateTime to);

    /// [SCHEDULER] Tìm khoản nợ quá hạn (due_date < now AND finished = false)
    /// Dùng cho DebtScheduler — nhắc khoản nợ đã quá hạn
    @Query("SELECT d FROM Debt d WHERE d.finished = false " +
           "AND d.dueDate IS NOT NULL " +
           "AND d.dueDate < :now")
    List<Debt> findOverdueDebts(@Param("now") LocalDateTime now);
}