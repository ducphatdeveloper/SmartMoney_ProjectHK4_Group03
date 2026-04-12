package fpt.aptech.server.repos;

import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import fpt.aptech.server.entity.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long>,
        JpaSpecificationExecutor<Transaction> {

    Optional<Transaction> findByIdAndAccount_Id(Long id, Integer accountId);

    /**
     * [ADMIN] Tìm kiếm giao dịch bằng Native Query để bỏ qua các bộ lọc Soft Delete.
     * Giải quyết lỗi "Không tìm thấy giao dịch" khi khôi phục.
     */
    @Query(value = "SELECT * FROM tTransactions WHERE id = :id", nativeQuery = true)
    Optional<Transaction> findAnyById(@Param("id") Long id);

    // =================================================================================
    // 2. CÁC HÀM LẤY DỮ LIỆU (READ / VIEW)
    // =================================================================================

    @Query("SELECT t FROM Transaction t " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId) " +
            "  AND t.deleted = false " +
            "ORDER BY t.transDate DESC")
    List<Transaction> findAllByFilters(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("savingGoalId") Integer savingGoalId
    );

    // =================================================================================
    // 3. CÁC HÀM BÁO CÁO & THỐNG KÊ (REPORT)
    // =================================================================================

    @Query("SELECT new fpt.aptech.server.dto.transaction.report.CategoryReportDTO(" +
            "    c.ctgName, " +       // Tên danh mục
            "    SUM(t.amount), " +   // Tổng tiền
            "    c.ctgType, " +       // Loại (Thu/Chi)
            "    c.ctgIconUrl" +      // Icon
            ") " +
            "FROM Transaction t " +
            "JOIN t.category c " +        // Kết nối bảng Category
            "WHERE t.account.id = :accountId " +                  // Lọc theo tài khoản
            "  AND t.transDate BETWEEN :startDate AND :endDate " + // Trong khoảng thời gian
            "  AND t.reportable = true " +                         // Chỉ tính giao dịch được báo cáo
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +             // Lọc theo Ví (nếu có)
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId) " + // Lọc theo Mục tiêu (nếu có)
            "  AND t.deleted = false " +                         // Chỉ tính giao dịch chưa bị xóa mềm
            "GROUP BY " +
            "    c.ctgName, " +
            "    c.ctgType, " +
            "    c.ctgIconUrl " +     // Gom nhóm theo danh mục
            "ORDER BY SUM(t.amount) DESC") // Sắp xếp giảm dần theo tổng tiền
    List<CategoryReportDTO> getReportByCategory(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("savingGoalId") Integer savingGoalId
    );

    @Query("SELECT SUM(" +
            "    CASE WHEN c.ctgType = true THEN t.amount ELSE -t.amount END" + // Thu thì cộng, Chi thì trừ
            ") " +
            "FROM Transaction t " +
            "JOIN t.category c " +        // Kết nối bảng Category
            "WHERE t.account.id = :accountId " +                  // Lọc theo tài khoản
            "  AND t.transDate < :startDate " + // Lấy tất cả giao dịch TRƯỚC ngày bắt đầu
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +             // Lọc theo Ví (nếu có)
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId) " + // Lọc theo Mục tiêu (nếu có)
            "  AND t.deleted = false")   // Chỉ tính giao dịch chưa bị xóa mềm
    BigDecimal calculateBalanceBeforeDate(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("walletId") Integer walletId,
            @Param("savingGoalId") Integer savingGoalId
    );

    @Query("SELECT new fpt.aptech.server.dto.transaction.report.DailyTrendDTO(" +
            "    CAST(t.transDate AS date), " +
            "    SUM(CASE WHEN c.ctgType = true  THEN t.amount ELSE 0 END), " +
            "    SUM(CASE WHEN c.ctgType = false THEN t.amount ELSE 0 END) " +
            ") " +
            "FROM Transaction t " +
            "JOIN t.category c " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND t.reportable = true " +
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId) " +
            "  AND (:categoryId IS NULL OR c.id = :categoryId) " +
            "  AND t.deleted = false " + // Chỉ lấy giao dịch chưa bị xóa mềm
            "GROUP BY CAST(t.transDate AS date) " +
            "ORDER BY CAST(t.transDate AS date) ASC")
    List<DailyTrendDTO> getDailyTrend(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("savingGoalId") Integer savingGoalId,
            @Param("categoryId") Integer categoryId
    );

    // =================================================================================
    // 4. CÁC HÀM CHO NGÂN SÁCH (BUDGET)
    // =================================================================================

    @Query("SELECT SUM(t.amount) " +
            "FROM Transaction t " +
            "JOIN t.category c " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND c.ctgType = false " + // Chỉ tính khoản CHI
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " + // Lọc theo ví của ngân sách (nếu có)
            "  AND (:allCategories = true OR c.id IN :categoryIds) " + // Lọc theo danh mục của ngân sách
            "  AND t.deleted = false")  // Chỉ tính giao dịch chưa bị xóa mềm
    BigDecimal sumExpenseForBudget(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("allCategories") Boolean allCategories,
            @Param("categoryIds") Set<Integer> categoryIds
    );

    @Query("SELECT t FROM Transaction t " +
            "JOIN t.category c " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND c.ctgType = false " +
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +
            "  AND (:allCategories = true OR c.id IN :categoryIds) " +
            "  AND t.deleted = false " + // Chỉ lấy giao dịch chưa bị xóa mềm
            "ORDER BY t.transDate DESC")
    List<Transaction> findTransactionsForBudget(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("allCategories") Boolean allCategories,
            @Param("categoryIds") Set<Integer> categoryIds
    );

    // =================================================================================
    // 5. CÁC HÀM CHO SỰ KIỆN (EVENT)
    // =================================================================================

    @Query("SELECT new fpt.aptech.server.dto.transaction.report.TransactionTotalDTO(" +
            "   SUM(CASE WHEN c.ctgType = true THEN t.amount ELSE 0 END), " +  // Tổng thu
            "   SUM(CASE WHEN c.ctgType = false THEN t.amount ELSE 0 END) " + // Tổng chi
            ") " +
            "FROM Transaction t JOIN t.category c " +
            "WHERE t.event.id = :eventId")
    TransactionTotalDTO getTotalsByEventId(@Param("eventId") Integer eventId);

    @Modifying
    @Query("UPDATE Transaction t SET t.event = null WHERE t.event.id = :eventId")
    void setEventIdToNullByEventId(@Param("eventId") Integer eventId);

    @Query("SELECT t FROM Transaction t WHERE t.event.id = :eventId ORDER BY t.transDate DESC")
    List<Transaction> findAllByEventId(@Param("eventId") Integer eventId);

    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.event.id = :eventId")
    void deleteAllByEventId(@Param("eventId") Integer eventId);

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = true, t.deletedAt = CURRENT_TIMESTAMP WHERE t.event.id = :eventId")
    void softDeleteAllByEventId(@Param("eventId") Integer eventId);

    // =================================================================================
    // 6. CÁC HÀM CHO SỔ NỢ (DEBT)
    // =================================================================================

    @Query("SELECT t FROM Transaction t WHERE t.debt.id = :debtId ORDER BY t.transDate DESC")
    List<Transaction> findAllByDebtId(@Param("debtId") Integer debtId);

    @Modifying
    @Query("UPDATE Transaction t SET t.debt = null WHERE t.debt.id = :debtId")
    void setDebtIdToNullByDebtId(@Param("debtId") Integer debtId);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t " +
            "WHERE t.debt.id = :debtId " +
            "AND t.category.id IN :categoryIds")
    BigDecimal sumAmountByDebtIdAndCategoryIds(
            @Param("debtId") Integer debtId,
            @Param("categoryIds") List<Integer> categoryIds);

    // =================================================================================
    // 7. CÁC HÀM CHO DANH MỤC (CATEGORY)
    // =================================================================================

    long countByCategoryIdAndAccountId(Integer categoryId, Integer accountId);

    List<Transaction> findAllByCategoryIdAndAccountId(Integer categoryId, Integer accountId);

    @Modifying
    @Query("UPDATE Transaction t SET t.category.id = :newCategoryId WHERE t.category.id = :oldCategoryId AND t.account.id = :accountId")
    void updateCategoryForUserTransactions(
            @Param("oldCategoryId") Integer oldCategoryId,
            @Param("newCategoryId") Integer newCategoryId,
            @Param("accountId") Integer accountId
    );

    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.category.id = :categoryId AND t.account.id = :accountId")
    void deleteAllByCategoryIdAndAccountId(
            @Param("categoryId") Integer categoryId,
            @Param("accountId") Integer accountId
    );

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = true, t.deletedAt = CURRENT_TIMESTAMP WHERE t.category.id = :categoryId AND t.account.id = :accountId")
    void softDeleteAllByCategoryIdAndAccountId(
            @Param("categoryId") Integer categoryId,
            @Param("accountId") Integer accountId);

    // =================================================================================
    // 8. CÁC HÀM HOÀN TIỀN KHI XÓA DANH MỤC
    // =================================================================================

    @Modifying
    @Query(value = "UPDATE tWallets " +
            "SET balance = balance - ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 1 AND t.wallet_id = tWallets.id AND t.acc_id = :accountId AND t.deleted = 0 " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT wallet_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND wallet_id IS NOT NULL AND acc_id = :accountId AND deleted = 0 " +
            ")", nativeQuery = true)
    void revertWalletBalanceForIncomeCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    @Modifying
    @Query(value = "UPDATE tWallets " +
            "SET balance = balance + ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 0 AND t.wallet_id = tWallets.id AND t.acc_id = :accountId AND t.deleted = 0 " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT wallet_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND wallet_id IS NOT NULL AND acc_id = :accountId AND deleted = 0 " +
            ")", nativeQuery = true)
    void revertWalletBalanceForExpenseCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    @Modifying
    @Query(value = "UPDATE tSavingGoals " +
            "SET current_amount = current_amount - ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 1 AND t.goal_id = tSavingGoals.id AND t.acc_id = :accountId AND t.deleted = 0 " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT goal_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND goal_id IS NOT NULL AND acc_id = :accountId AND deleted = 0 " +
            ")", nativeQuery = true)
    void revertGoalBalanceForIncomeCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    @Modifying
    @Query(value = "UPDATE tSavingGoals " +
            "SET current_amount = current_amount + ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 0 AND t.goal_id = tSavingGoals.id AND t.acc_id = :accountId AND t.deleted = 0 " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT goal_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND goal_id IS NOT NULL AND acc_id = :accountId AND deleted = 0 " +
            ")", nativeQuery = true)
    void revertGoalBalanceForExpenseCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    // =================================================================================
    // 9. CÁC HÀM CHO ADMIN (ADMIN)
    // =================================================================================

    @Query("SELECT c.ctgName, COALESCE(SUM(t.amount), 0), c.ctgType, c.ctgIconUrl, p.ctgName " +
            "FROM Category c " +
            "LEFT JOIN c.parent p " +
            "LEFT JOIN Transaction t ON t.category = c " +
            "AND t.transDate BETWEEN :startDate AND :endDate " +
            "AND t.deleted = false " +
            "GROUP BY c.id, c.ctgName, c.ctgType, c.ctgIconUrl, p.ctgName")
    List<Object[]> getGlobalCategoryStats(@Param("startDate") LocalDateTime startDate,
                                          @Param("endDate") LocalDateTime endDate);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t " +
            "WHERE t.transDate BETWEEN :startDate AND :endDate AND t.deleted = false")
    BigDecimal getTotalVolumeRange(@Param("startDate") LocalDateTime startDate,
                                   @Param("endDate") LocalDateTime endDate);

    @Query("SELECT g.goalName, SUM(t.amount), g.id " +
            "FROM Transaction t " +
            "JOIN t.savingGoal g " +
            "WHERE t.transDate BETWEEN :startDate AND :endDate " +
            "  AND t.deleted = false " +
            "GROUP BY g.id, g.goalName")
    List<Object[]> getGlobalGoalStats(@Param("startDate") LocalDateTime startDate,
                                      @Param("endDate") LocalDateTime endDate);

    List<Transaction> findAllByAmountGreaterThanAndTransDateAfter(BigDecimal amount, LocalDateTime since);

    @Query("SELECT t FROM Transaction t " +
            "LEFT JOIN FETCH t.wallet w " +
            "LEFT JOIN FETCH t.category c " +
            "WHERE t.account.id = :userId " +
            "AND ((:onlyDeleted = true AND t.deleted = true) OR " +
            "(:onlyDeleted = false AND (:includeDeleted = true OR t.deleted = false))) " +
            "AND (:isIncome IS NULL OR c.ctgType = :isIncome) " +
            "ORDER BY CASE WHEN :onlyDeleted = true THEN t.deletedAt ELSE t.transDate END DESC")
    Page<Transaction> findAllUserTransactionsWithFilter(
            @Param("userId") Integer userId,
            @Param("includeDeleted") boolean includeDeleted,
            @Param("onlyDeleted") boolean onlyDeleted,
            @Param("isIncome") Boolean isIncome,
            Pageable pageable);

    @Query("SELECT t FROM Transaction t " +
            "LEFT JOIN FETCH t.wallet w " +
            "LEFT JOIN FETCH t.category c " +
            "WHERE t.account.id = :userId " +
            "AND ((:onlyDeleted = true AND t.deleted = true) OR " +
            "(:onlyDeleted = false AND (:includeDeleted = true OR t.deleted = false))) " +
            "AND (:isIncome IS NULL OR c.ctgType = :isIncome) " +
            "ORDER BY CASE WHEN :onlyDeleted = true THEN t.deletedAt ELSE t.transDate END DESC")
    List<Transaction> findAllUserTransactionsWithFilter(
            @Param("userId") Integer userId,
            @Param("includeDeleted") boolean includeDeleted,
            @Param("onlyDeleted") boolean onlyDeleted,
            @Param("isIncome") Boolean isIncome);

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = false, t.deletedAt = null WHERE t.id = :id")
    void restoreTransaction(@Param("id") Long id);

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = false, t.deletedAt = null WHERE t.account.id = :userId AND t.deleted = true")
    void restoreAllUserTransactions(@Param("userId") Integer userId);

    // =================================================================================
    // 10. CÁC HÀM CHO PLANNED TRANSACTION
    // =================================================================================

    List<Transaction> findAllByPlannedTransactionIdAndAccountIdOrderByTransDateDesc(Integer plannedId, Integer accountId);

    @Query("SELECT CASE WHEN COUNT(t) > 0 THEN true ELSE false END FROM Transaction t WHERE t.plannedTransaction.id = :plannedId AND t.account.id = :accountId AND t.transDate BETWEEN :startTime AND :endTime")
    boolean existsByPlannedTransactionIdAndAccountIdAndTransDateBetween(
            @Param("plannedId") Integer plannedId,
            @Param("accountId") Integer accountId,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    @Modifying
    @Query("UPDATE Transaction t SET t.plannedTransaction = null WHERE t.plannedTransaction.id = :plannedId AND t.account.id = :accountId")
    void clearPlannedTransactionLink(
            @Param("plannedId") Integer plannedId,
            @Param("accountId") Integer accountId);

    // =================================================================================
    // 11. CÁC HÀM SOFT DELETE CASCADE
    // =================================================================================

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = true, t.deletedAt = CURRENT_TIMESTAMP WHERE t.wallet.id = :walletId")
    void softDeleteAllByWalletId(@Param("walletId") Integer walletId);

    @Modifying
    @Query("UPDATE Transaction t SET t.deleted = true, t.deletedAt = CURRENT_TIMESTAMP WHERE t.savingGoal.id = :goalId")
    void softDeleteAllBySavingGoalId(@Param("goalId") Integer goalId);

    @Query("SELECT t FROM Transaction t WHERE t.account.id = :accountId ORDER BY t.transDate DESC")
    Page<Transaction> findAllByAccount_IdOrderByTransDateDesc(@Param("accountId") Integer accountId, Pageable pageable);

    @Query("SELECT t FROM Transaction t WHERE t.transDate > :since")
    List<Transaction> findAllByTransDateAfter(@Param("since") LocalDateTime since);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.account.id = :accountId AND t.category.ctgType = :isIncome")
    BigDecimal sumLifetimeByAccountAndType(@Param("accountId") Integer accountId, @Param("isIncome") Boolean isIncome);

    @Query("SELECT t FROM Transaction t WHERE t.account.id = :accountId ORDER BY t.transDate DESC")
    List<Transaction> findAllByAccount_IdOrderByTransDateDesc(@Param("accountId") Integer accountId);

    @Query("SELECT COUNT(t) FROM Transaction t " +
           "WHERE t.account.id = :accountId " +
           "  AND t.amount = :amount " +
           "  AND t.createdAt >= :since " +
           "  AND t.deleted = false")
    long countSameAmountCreatedAfter(
            @Param("accountId") Integer accountId,
            @Param("amount") BigDecimal amount,
            @Param("since") LocalDateTime since
    );

    @Query("SELECT CASE WHEN COUNT(t) > 0 THEN true ELSE false END FROM Transaction t " +
           "WHERE t.account.id = :accountId " +
           "  AND t.amount = :amount " +
           "  AND t.transDate BETWEEN :from AND :to " +
           "  AND t.deleted = false")
    boolean existsSameAmountInWindow(
            @Param("accountId") Integer accountId,
            @Param("amount") BigDecimal amount,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to
    );
}
