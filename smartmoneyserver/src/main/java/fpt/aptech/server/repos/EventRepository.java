package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Event;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface EventRepository extends JpaRepository<Event, Integer> {
    /**
     * Tìm tất cả sự kiện của một user dựa trên trạng thái 'finished'.
     * Dùng cho 2 tab "Đang diễn ra" và "Đã kết thúc".
     * @param accountId ID của user.
     * @param isFinished Trạng thái hoàn thành (true hoặc false).
     * @return Danh sách các sự kiện.
     */
    List<Event> findAllByAccountIdAndFinished(Integer accountId, Boolean isFinished);

    // ── SCHEDULER QUERIES ───────────────────────────────────────────────────────────

    // [SCHEDULER] Tìm sự kiện chưa kết thúc có endDate = ngày cụ thể (dùng cho nhắc mốc 7 ngày)
    // Bảo mật: Trả về entity kèm account → EventScheduler gửi thông báo đúng chủ sở hữu
    @Query("SELECT e FROM Event e WHERE e.finished = false AND e.endDate = :targetDate")
    List<Event> findActiveEventsByEndDate(@Param("targetDate") LocalDate targetDate);

    // [SCHEDULER] Tìm sự kiện quá hạn chưa hoàn tất (endDate < today AND finished=false)
    // Dùng cho EventScheduler auto-complete
    @Query("SELECT e FROM Event e WHERE e.finished = false AND e.endDate < :today")
    List<Event> findOverdueUnfinishedEvents(@Param("today") LocalDate today);

    // ── SOFT DELETE CASCADE ───────────────────────────────────────────────────────────
    // Dùng Native SQL để bỏ qua @SQLRestriction("deleted = 0") trên bảng tTransactions,
    // đảm bảo tìm được sự kiện ngay cả khi giao dịch liên kết đã bị xóa mềm trước đó.

    /// [CASCADE] Xóa mềm tất cả sự kiện có giao dịch thuộc một ví (cascade từ Wallet soft delete)
    @Modifying
    @Query(value = "UPDATE tEvents SET deleted = 1, deleted_at = CURRENT_TIMESTAMP " +
                   "WHERE id IN (SELECT DISTINCT event_id FROM tTransactions " +
                   "             WHERE wallet_id = :walletId AND event_id IS NOT NULL)",
           nativeQuery = true)
    void softDeleteAllByWalletId(@Param("walletId") Integer walletId);

    /// [CASCADE] Xóa mềm tất cả sự kiện có giao dịch thuộc một mục tiêu (cascade từ SavingGoal soft delete)
    @Modifying
    @Query(value = "UPDATE tEvents SET deleted = 1, deleted_at = CURRENT_TIMESTAMP " +
                   "WHERE id IN (SELECT DISTINCT event_id FROM tTransactions " +
                   "             WHERE goal_id = :goalId AND event_id IS NOT NULL)",
           nativeQuery = true)
    void softDeleteAllBySavingGoalId(@Param("goalId") Integer goalId);
}
