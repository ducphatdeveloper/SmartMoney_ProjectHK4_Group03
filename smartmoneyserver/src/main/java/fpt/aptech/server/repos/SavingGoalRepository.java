package fpt.aptech.server.repos;

import fpt.aptech.server.entity.SavingGoal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface SavingGoalRepository extends JpaRepository<SavingGoal, Integer> {

    // =================================================================================
    // 1. CÁC HÀM CRUD CƠ BẢN (Kế thừa từ JpaRepository)
    // =================================================================================
    // - save(SavingGoal g)   : Tạo mới (Create) hoặc Cập nhật (Update)
    // - findById(Integer id) : Xem chi tiết (Read Detail)
    // - deleteById(Integer id): Xóa cứng (Hard Delete) - không dùng, dùng Soft Delete qua goalStatus
    // - findAll()            : Lấy tất cả (không dùng trực tiếp — luôn lọc theo accId)

    // =================================================================================
    // 2. CÁC HÀM LẤY DANH SÁCH (READ / LIST)
    // =================================================================================

    /**
     * [2.1] Lấy tất cả mục tiêu của một tài khoản (kể cả đã hủy).
     */
    List<SavingGoal> findByAccount_Id(Integer accId);

    /**
     * [2.2] Lấy tất cả mục tiêu chưa bị hủy (goalStatus != CANCELLED=3).
     * Dùng cho màn hình danh sách mục tiêu — ẩn những mục đã hủy.
     */
    List<SavingGoal> findByAccount_IdAndGoalStatusNot(Integer accId, Integer status);

    /**
     * [2.3] Tìm mục tiêu theo tên (không phân biệt hoa/thường), loại trừ đã hủy.
     * Dùng cho thanh tìm kiếm trong màn hình danh sách mục tiêu.
     */
    List<SavingGoal> findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
            Integer accId,
            String name,
            Integer status
    );

    // =================================================================================
    // 3. CÁC HÀM LẤY CHI TIẾT (READ / DETAIL)
    // =================================================================================

    /**
     * [3.1] Lấy một mục tiêu theo ID + accId (kiểm tra quyền sở hữu).
     */
    Optional<SavingGoal> findByIdAndAccount_Id(Integer id, Integer userId);

    /**
     * [3.2] Lấy một mục tiêu theo ID + accId, loại trừ đã hủy.
     * Dùng trong getOwnedGoal() — không cho thao tác trên mục tiêu đã hủy.
     */
    Optional<SavingGoal> findByIdAndAccount_IdAndGoalStatusNot(
            Integer id,
            Integer userId,
            Integer status
    );

    // =================================================================================
    // 4. CÁC HÀM KIỂM TRA (VALIDATE)
    // =================================================================================

    /**
     * [4.1] Kiểm tra tên mục tiêu đã tồn tại chưa (tránh trùng tên, loại trừ đã hủy).
     * Dùng trước khi tạo mới hoặc đổi tên mục tiêu.
     */
    boolean existsByGoalNameAndAccount_IdAndGoalStatusNot(
            String goalName,
            Integer accountId,
            Integer status
    );

    // =================================================================================
    // 5. CÁC HÀM BÁO CÁO & THỐNG KÊ (REPORT)
    // =================================================================================

    /**
     * [5.1] Tính tổng số tiền hiện có trong tất cả mục tiêu đang hoạt động.
     * - Loại trừ goalStatus = 3 (CANCELLED).
     * - Chỉ tính các goal có reportable = true.
     * Dùng cho Dashboard tổng quan tài sản.
     */
    @Query("SELECT SUM(sg.currentAmount) FROM SavingGoal sg " +
           "WHERE sg.account.id = :accountId " +
           "  AND sg.goalStatus != 3 " +      // Loại trừ CANCELLED
           "  AND sg.reportable = true " +     // Chỉ tính mục tiêu được báo cáo
           "  AND sg.deleted = false")         // Chỉ tính mục tiêu chưa bị xóa mềm
    BigDecimal sumCurrentAmountByAccountId(@Param("accountId") Integer accountId);

    // =================================================================================
    // 6. CÁC HÀM CHO SCHEDULER
    // =================================================================================

    /**
     * [6.1] Tìm các mục tiêu ACTIVE đã quá hạn (endDate < hôm nay).
     * Dùng trong SavingGoalScheduler.checkOverdueGoals() — chạy lúc 1:00 AM.
     * → Chuyển trạng thái sang OVERDUE + gửi thông báo.
     */
    List<SavingGoal> findByGoalStatusAndEndDateBefore(
            Integer goalStatus,
            LocalDate date
    );

    /**
     * [6.2] Tìm các mục tiêu ACTIVE sắp đến hạn trong khoảng [start, end].
     * Dùng trong SavingGoalScheduler.remindNearDeadlineGoals() — chạy lúc 8:00 AM.
     * → Gửi thông báo nhắc nhở (mặc định: còn <= 7 ngày).
     */
    List<SavingGoal> findByGoalStatusAndEndDateBetween(
            Integer goalStatus,
            LocalDate start,
            LocalDate end
    );
}
