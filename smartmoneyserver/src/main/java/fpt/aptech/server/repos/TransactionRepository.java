package fpt.aptech.server.repos;

import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.TransactionTotalDTO;
import fpt.aptech.server.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional; //<< Nam
import java.util.Set;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long>,
        JpaSpecificationExecutor<Transaction> {

    Optional<Transaction> findByIdAndAccount_Id(Long id, Integer accountId); // << Nam

    // =================================================================================
    // 1. CÁC HÀM CRUD CƠ BẢN (Kế thừa từ JpaRepository)
    // =================================================================================
    // - save(Transaction t): Tạo mới (Create) hoặc Cập nhật (Update)
    // - findById(Long id): Xem chi tiết (Read Detail)
    // - deleteById(Long id): Xóa cứng (Hard Delete) - Ít dùng, thường dùng Soft Delete
    // - findAll(Specification s): Tìm kiếm nâng cao (Search Advanced) - Kế thừa từ JpaSpecificationExecutor

    // =================================================================================
    // 2. CÁC HÀM LẤY DỮ LIỆU (READ / VIEW)
    // =================================================================================

    /// [VIEW] Lấy danh sách giao dịch theo bộ lọc (Dùng cho cả Báo cáo và Nhật ký)
    @Query("SELECT t FROM Transaction t " +
            "WHERE t.account.id = :accountId " +                  // Lọc theo tài khoản
            "  AND t.transDate BETWEEN :startDate AND :endDate " + // Trong khoảng thời gian
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +             // Lọc theo Ví (nếu có)
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId) " + // Lọc theo Mục tiêu (nếu có)
            "ORDER BY t.transDate DESC") // Sắp xếp giảm dần theo ngày
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

    /// [REPORT] Thống kê tổng tiền theo từng danh mục (Biểu đồ tròn)
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

    /// [REPORT] Tính số dư đầu kỳ (Opening Balance)
    @Query("SELECT SUM(" +
            "    CASE WHEN c.ctgType = true THEN t.amount ELSE -t.amount END" + // Thu thì cộng, Chi thì trừ
            ") " +
            "FROM Transaction t " +
            "JOIN t.category c " +        // Kết nối bảng Category
            "WHERE t.account.id = :accountId " +                  // Lọc theo tài khoản
            "  AND t.transDate < :startDate " + // Lấy tất cả giao dịch TRƯỚC ngày bắt đầu
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +             // Lọc theo Ví (nếu có)
            "  AND (:savingGoalId IS NULL OR t.savingGoal.id = :savingGoalId)")   // Lọc theo Mục tiêu (nếu có)
    BigDecimal calculateBalanceBeforeDate(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("walletId") Integer walletId,
            @Param("savingGoalId") Integer savingGoalId
    );

    /// [REPORT] Thống kê thu/chi theo từng ngày (Biểu đồ cột/đường)
    // Spring Boot 3.5.x dùng Hibernate 6 → JPQL hỗ trợ CAST(x AS date) chuẩn JPA 3.1
    // Không cần native query, giữ nguyên DailyTrendDTO record constructor
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

    /// [BUDGET] Tính tổng chi tiêu thực tế cho một ngân sách
    @Query("SELECT SUM(t.amount) " +
            "FROM Transaction t " +
            "JOIN t.category c " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND c.ctgType = false " + // Chỉ tính khoản CHI
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " + // Lọc theo ví của ngân sách (nếu có)
            "  AND (:allCategories = true OR c.id IN :categoryIds)")  // Lọc theo danh mục của ngân sách
    BigDecimal sumExpenseForBudget(
            @Param("accountId") Integer accountId,
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            @Param("walletId") Integer walletId,
            @Param("allCategories") Boolean allCategories,
            @Param("categoryIds") Set<Integer> categoryIds
    );

    /// [BUDGET] Lấy danh sách giao dịch CHI thuộc ngân sách (cho GET /api/budgets/{id}/transactions)
    /// - allCategories=true  → lấy tất cả giao dịch chi trong khoảng thời gian + ví của ngân sách
    /// - allCategories=false → lọc thêm theo danh sách categoryIds
    @Query("SELECT t FROM Transaction t " +
            "JOIN t.category c " +
            "WHERE t.account.id = :accountId " +
            "  AND t.transDate BETWEEN :startDate AND :endDate " +
            "  AND c.ctgType = false " +
            "  AND (:walletId IS NULL OR t.wallet.id = :walletId) " +
            "  AND (:allCategories = true OR c.id IN :categoryIds) " +
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

    /// [EVENT] Tính tổng thu và tổng chi cho một sự kiện.
    @Query("SELECT new fpt.aptech.server.dto.transaction.report.TransactionTotalDTO(" +
            "   SUM(CASE WHEN c.ctgType = true THEN t.amount ELSE 0 END), " +  // Tổng thu
            "   SUM(CASE WHEN c.ctgType = false THEN t.amount ELSE 0 END) " + // Tổng chi
            ") " +
            "FROM Transaction t JOIN t.category c " +
            "WHERE t.event.id = :eventId")
    TransactionTotalDTO getTotalsByEventId(@Param("eventId") Integer eventId);

    /// [EVENT] Set event_id = null cho tất cả giao dịch thuộc một sự kiện.
    /// Dùng khi người dùng chọn "Chỉ xóa sự kiện".
    @Modifying
    @Query("UPDATE Transaction t SET t.event = null WHERE t.event.id = :eventId")
    void setEventIdToNullByEventId(@Param("eventId") Integer eventId);

    /// [EVENT] Lấy danh sách giao dịch theo eventId (cho trang XEM GIAO DỊCH)
    @Query("SELECT t FROM Transaction t WHERE t.event.id = :eventId ORDER BY t.transDate DESC")
    List<Transaction> findAllByEventId(@Param("eventId") Integer eventId);

    /// [EVENT] Xóa cứng giao dịch theo eventId (cho nút XÓA CẢ HAI)
    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.event.id = :eventId")
    void deleteAllByEventId(@Param("eventId") Integer eventId);

    // =================================================================================
    // 6. CÁC HÀM CHO SỔ NỢ (DEBT)
    // =================================================================================

    /// [DEBT] Lấy danh sách giao dịch theo debtId (lịch sử trả/thu nợ)
    @Query("SELECT t FROM Transaction t WHERE t.debt.id = :debtId ORDER BY t.transDate DESC")
    List<Transaction> findAllByDebtId(@Param("debtId") Integer debtId);

    /// [DEBT] Set debt_id = null khi xóa debt (giữ lại giao dịch)
    @Modifying
    @Query("UPDATE Transaction t SET t.debt = null WHERE t.debt.id = :debtId")
    void setDebtIdToNullByDebtId(@Param("debtId") Integer debtId);

    /// [DEBT] Tính tổng amount theo debtId và danh sách categoryId
    /// Dùng cho recalculateDebt() — tính totalAmount và paidAmount
    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t " +
            "WHERE t.debt.id = :debtId " +
            "AND t.category.id IN :categoryIds")
    BigDecimal sumAmountByDebtIdAndCategoryIds(
            @Param("debtId") Integer debtId,
            @Param("categoryIds") List<Integer> categoryIds);

    // =================================================================================
    // 7. CÁC HÀM CHO DANH MỤC (CATEGORY)
    // =================================================================================

    /// [CATEGORY] Đếm số giao dịch thuộc một danh mục của một user
    long countByCategoryIdAndAccountId(Integer categoryId, Integer accountId);

    /// [CATEGORY] Lấy tất cả giao dịch thuộc một danh mục của một user (để hoàn tiền)
    List<Transaction> findAllByCategoryIdAndAccountId(Integer categoryId, Integer accountId);

    /// [CATEGORY] Cập nhật hàng loạt: chuyển các giao dịch từ danh mục cũ sang danh mục mới
    @Modifying
    @Query("UPDATE Transaction t SET t.category.id = :newCategoryId WHERE t.category.id = :oldCategoryId AND t.account.id = :accountId")
    void updateCategoryForUserTransactions(
            @Param("oldCategoryId") Integer oldCategoryId,
            @Param("newCategoryId") Integer newCategoryId,
            @Param("accountId") Integer accountId
    );

    /// [CATEGORY] Xóa hàng loạt các giao dịch thuộc một danh mục
    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.category.id = :categoryId AND t.account.id = :accountId")
    void deleteAllByCategoryIdAndAccountId(
            @Param("categoryId") Integer categoryId,
            @Param("accountId") Integer accountId
    );

    // =================================================================================
    // 8. CÁC HÀM HOÀN TIỀN KHI XÓA DANH MỤC (NATIVE SQL ĐỂ TRÁNH TRANSIENT EXCEPTION)
    // =================================================================================

    // 8.1 Hoàn tiền VÍ (Giao dịch THU -> Trừ tiền)
    @Modifying
    @Query(value = "UPDATE tWallets " +
            "SET balance = balance - ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 1 AND t.wallet_id = tWallets.id AND t.acc_id = :accountId " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT wallet_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND wallet_id IS NOT NULL AND acc_id = :accountId " +
            ")", nativeQuery = true)
    void revertWalletBalanceForIncomeCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    // 8.2 Hoàn tiền VÍ (Giao dịch CHI -> Cộng tiền)
    @Modifying
    @Query(value = "UPDATE tWallets " +
            "SET balance = balance + ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 0 AND t.wallet_id = tWallets.id AND t.acc_id = :accountId " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT wallet_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND wallet_id IS NOT NULL AND acc_id = :accountId " +
            ")", nativeQuery = true)
    void revertWalletBalanceForExpenseCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    // 8.3 Hoàn tiền MỤC TIÊU (Giao dịch THU -> Trừ tiền)
    @Modifying
    @Query(value = "UPDATE tSavingGoals " +
            "SET current_amount = current_amount - ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 1 AND t.goal_id = tSavingGoals.id AND t.acc_id = :accountId " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT goal_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND goal_id IS NOT NULL AND acc_id = :accountId " +
            ")", nativeQuery = true)
    void revertGoalBalanceForIncomeCategory(@Param("categoryId") Integer categoryId, @Param("accountId") Integer accountId);

    // 8.4 Hoàn tiền MỤC TIÊU (Giao dịch CHI -> Cộng tiền)
    @Modifying
    @Query(value = "UPDATE tSavingGoals " +
            "SET current_amount = current_amount + ( " +
            "   SELECT COALESCE(SUM(t.amount), 0) FROM tTransactions t " +
            "   JOIN tCategories c ON t.ctg_id = c.id " +
            "   WHERE t.ctg_id = :categoryId AND c.ctg_type = 0 AND t.goal_id = tSavingGoals.id AND t.acc_id = :accountId " +
            ") " +
            "WHERE id IN ( " +
            "   SELECT DISTINCT goal_id FROM tTransactions " +
            "   WHERE ctg_id = :categoryId AND goal_id IS NOT NULL AND acc_id = :accountId " +
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
           "GROUP BY c.id, c.ctgName, c.ctgType, c.ctgIconUrl, p.ctgName")
    List<Object[]> getGlobalCategoryStats(@Param("startDate") LocalDateTime startDate,
                                          @Param("endDate") LocalDateTime endDate);
    // Tìm các giao dịch có số tiền lớn hơn ngưỡng và phát sinh sau thời điểm xác định
    List<Transaction> findAllByAmountGreaterThanAndTransDateAfter(BigDecimal amount, LocalDateTime since);

    // =================================================================================
    // 10. CÁC HÀM CHO PLANNED TRANSACTION (Giao dịch định kỳ / Hóa đơn)
    // =================================================================================

    /**
     * [PLANNED] Lấy danh sách giao dịch được tạo ra từ một PlannedTransaction cụ thể.
     * Dùng cho màn hình "Xem giao dịch" của một Hóa đơn/Giao dịch định kỳ.
     */
    List<Transaction> findAllByPlannedTransactionIdAndAccountIdOrderByTransDateDesc(Integer plannedId, Integer accountId);

    /**
     * [PLANNED] Check xem Planned transaction đã có giao dịch trong khoảng thời gian chưa.
     * Dùng khi update Recurring/Bill để check xem nextDueDate hôm nay đã có giao dịch chưa.
     */
    @Query("SELECT CASE WHEN COUNT(t) > 0 THEN true ELSE false END FROM Transaction t WHERE t.plannedTransaction.id = :plannedId AND t.account.id = :accountId AND t.transDate BETWEEN :startTime AND :endTime")
    boolean existsByPlannedTransactionIdAndAccountIdAndTransDateBetween(
            @Param("plannedId") Integer plannedId,
            @Param("accountId") Integer accountId,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    /**
     * [PLANNED] Set planned_id = NULL cho các giao dịch thuộc một PlannedTransaction.
     * Dùng khi xóa Hóa đơn hoặc Giao dịch định kỳ (giữ lại transaction, chỉ cắt liên kết).
     * SourceType sẽ vẫn là PLANNED (5) để tracking lịch sử.
     */
    @Modifying
    @Query("UPDATE Transaction t SET t.plannedTransaction = null WHERE t.plannedTransaction.id = :plannedId AND t.account.id = :accountId")
    void clearPlannedTransactionLink(
            @Param("plannedId") Integer plannedId,
            @Param("accountId") Integer accountId);
}
