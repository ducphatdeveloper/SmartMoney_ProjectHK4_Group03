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
import java.util.Set;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long>,
        JpaSpecificationExecutor<Transaction> {

    // =================================================================================
    // 1. CÁC HÀM CRUD CƠ BẢN (Kế thừa từ JpaRepository)
    // =================================================================================
    // - save(Transaction t): Tạo mới (Create) hoặc Cập nhật (Update)
    // - findById(Integer id): Xem chi tiết (Read Detail)
    // - deleteById(Integer id): Xóa cứng (Hard Delete) - Ít dùng, thường dùng Soft Delete
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
}
