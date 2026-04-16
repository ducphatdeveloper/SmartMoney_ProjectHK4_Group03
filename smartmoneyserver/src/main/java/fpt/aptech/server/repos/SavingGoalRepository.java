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
     * [2.2] Lấy tất cả mục tiêu của tài khoản theo status cụ thể (không dùng nữa trực tiếp).
     * Giữ lại để tương thích nếu module khác dùng.
     */
    List<SavingGoal> findByAccount_IdAndGoalStatusNot(Integer accId, Integer status);

    /**
     * [2.3] Tìm mục tiêu theo tên (không phân biệt hoa/thường), lọc theo status.
     * Giữ lại để tương thích nếu module khác dùng.
     */
    List<SavingGoal> findByAccount_IdAndGoalNameContainingIgnoreCaseAndGoalStatusNot(
            Integer accId,
            String name,
            Integer status
    );

    /**
     * [2.4] Lấy danh sách saving goal hợp lệ để hiển thị trong Dropdown chọn nguồn tiền
     *       của module Transaction (Create / Edit).
     *
     * Điều kiện lọc:
     *   • deleted = false   — chưa bị xóa mềm
     *   • finished = false  — chưa chốt sổ / chưa hủy hoàn toàn
     *   → Trả về các goal ở trạng thái: ACTIVE(1), COMPLETED(2-chưa chốt), OVERDUE(4)
     *   → Loại bỏ: CANCELLED+finished=true, COMPLETED+finished=true, deleted=true
     *
     * Dùng ở: TransactionServiceImpl khi load dropdown nguồn tiền.
     */
    @Query("SELECT sg FROM SavingGoal sg " +
            "WHERE sg.account.id = :accountId " +
            "  AND sg.deleted = false " +
            "  AND sg.finished = false " +
            "ORDER BY sg.goalName ASC")
    List<SavingGoal> findAvailableForTransaction(@Param("accountId") Integer accountId);

    /**
     * [2.5] Lay danh sach muc tieu theo trang thai finished (phuc vu API getAll?isFinished=...).
     *   isFinished = false -> Tab Active: ACTIVE(1), COMPLETED(2-chua chot), OVERDUE(4)
     *   isFinished = true  -> Tab Finished: COMPLETED+chot so, CANCELLED
     * Spring Data JPA tu sinh query: WHERE account_id = ? AND finished = ? AND deleted = 0
     */
    List<SavingGoal> findByAccount_IdAndFinished(Integer accId, Boolean finished);

    // =================================================================================
    // 3. CÁC HÀM LẤY CHI TIẾT (READ / DETAIL)
    // =================================================================================

    /**
     * [3.1] Lấy một mục tiêu theo ID + accId (kiểm tra quyền sở hữu).
     */
    Optional<SavingGoal> findByIdAndAccount_Id(Integer id, Integer userId);

    /**
     * [3.2] Lấy một mục tiêu theo ID + accId, lọc theo status.
     * Giữ lại để tương thích nếu module khác dùng.
     * Lưu ý: @SQLRestriction("deleted=0") đã tự loại trừ các goal đã xóa mềm.
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
     * [4.1] Kiểm tra tên mục tiêu đã tồn tại chưa (tránh trùng tên, loại trừ đã xóa mềm).
     * @SQLRestriction("deleted=0") đã xử lý, không cần thêm điều kiện deleted.
     * Truyền statusToExclude = CANCELLED(3) để không trùng với goal đang tạm dừng.
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
     *       Dùng cho Dashboard tổng quan tài sản — chỉ tính các goal ĐANG CÓ TIỀN thực sự.
     *
     * Điều kiện lọc:
     *   • deleted = false       — chưa bị xóa mềm
     *   • finished = false      — chưa chốt sổ (tiền đã đổ về wallet rồi thì không tính nữa)
     *   • goalStatus != 3       — loại trừ CANCELLED (đã hủy giữa chừng)
     *   • reportable = true     — chỉ tính mục tiêu được báo cáo
     *
     * Lý do loại finished=true: khi chốt sổ/hủy, tiền đã được chuyển về Wallet rồi.
     * Nếu vẫn tính thì sẽ bị đếm 2 lần (cả trong wallet lẫn saving goal).
     *
     * Dùng ở: WalletServiceImpl.getTotalBalance() để cộng vào tổng tài sản toàn bộ ứng dụng.
     */
    @Query("SELECT COALESCE(SUM(sg.currentAmount), 0) FROM SavingGoal sg " +
            "WHERE sg.account.id = :accountId " +
            "  AND sg.deleted = false " +
            "  AND sg.finished = false " +
            "  AND sg.goalStatus != 3 " +      // Loại trừ CANCELLED
            "  AND sg.reportable = true")       // Chỉ tính mục tiêu được báo cáo
    BigDecimal sumActiveCurrentAmountByAccountId(@Param("accountId") Integer accountId);

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