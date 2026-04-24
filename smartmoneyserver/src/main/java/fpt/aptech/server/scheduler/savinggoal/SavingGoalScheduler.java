package fpt.aptech.server.scheduler.savinggoal;

import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.savinggoal.GoalStatus;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.context.annotation.Lazy;
import org.springframework.transaction.annotation.Propagation;


import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Scheduler quản lý mục tiêu tiết kiệm.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — checkOverdueGoals():        1:00 AM mỗi ngày → Chuyển ACTIVE → OVERDUE nếu quá hạn
 *   JOB 2 — remindNearDeadlineGoals():   8:00 AM mỗi ngày → Nhắc mục tiêu sắp hết hạn (≤ 7 ngày)
 * ────────────────────────────────────────────────────────────────────────
 * Lý do phân khung giờ:
 *   - 1h sáng: Xử lý nền (cập nhật status) khi hệ thống ít tải
 *   - 8h sáng: Gửi nhắc nhở khi user mở app buổi sáng
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *
 *   1. savingOverdue()        → "Mục tiêu quá hạn ⚠️" — đã quá endDate mà chưa đủ tiền (JOB 1)
 *      Content: "Mục tiêu quá hạn ⚠️: Mục tiêu 'Mua xe máy' đã quá hạn (đến hạn 01/05/2026). Đã tiết kiệm 8.000.000 ₫ / 10.000.000 ₫ (80%)."
 *
 *   2. savingNearDeadline()   → "Nhắc mục tiêu ⏰" — còn ≤ 7 ngày và chưa đủ tiền (JOB 2)
 *      Content: "Nhắc mục tiêu ⏰: Mục tiêu 'Mua xe máy' còn 5 ngày đến hạn (01/05/2026). Đã tiết kiệm 8.000.000 ₫ / 10.000.000 ₫ (80%)."
 *
 * ─── STATUS MATRIX ────────────────────────────────────────────────────────
 * ACTIVE(1)    → Đang chạy, scheduler xử lý bình thường
 * COMPLETED(2) → Đã hoàn thành (đủ tiền), scheduler bỏ qua
 * CANCELLED(3) → Da ket thuc som (finished=true) — KHONG the kich hoat lai.
 *                Scheduler bo qua — chi xu ly ACTIVE.
 * OVERDUE(4)   → Quá hạn, scheduler bỏ qua (đã chuyển status xong rồi)
 * ─────────────────────────────────────────────────────────────────────────
 * Lưu ý: @SQLRestriction("deleted=0") trên entity SavingGoal đảm bảo
 *         các goal đã xóa mềm (deleted=true) không bao giờ vào scheduler.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SavingGoalScheduler {
    @Lazy
    @Autowired
    private SavingGoalScheduler self; //bỏ final

    private final SavingGoalRepository savingGoalRepository;
    private final NotificationService notificationService;

    // Nhắc trước khi đến hạn bao nhiêu ngày
    private static final int NEAR_DEADLINE_DAYS = 7;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Chuyển trạng thái mục tiêu quá hạn (1:00 AM mỗi ngày)
    // Lý do 1h sáng: Xử lý nền cập nhật status, cùng khung giờ với
    // BudgetScheduler.renewRecurringBudgets(), EventScheduler.autoCompleteEvents().
    // ══════════════════════════════════════════════════════════════════════

    /**
     * JOB 1: Chuyển ACTIVE → OVERDUE nếu đã quá endDate.
     * Chạy lúc 1:00 AM mỗi ngày.
     *
     * → NotificationMessages.savingOverdue()
     *   Thông báo tạo ra: Title="Mục tiêu quá hạn ⚠️"
     *   Content="Mục tiêu tiết kiệm \"Mua xe máy SH\" đã quá hạn nhưng vẫn còn thiếu 45.000.000 ₫. Bạn có muốn gia hạn?"
     */
    @Scheduled(cron = "0 0 1 * * ?") // 1:00 AM mỗi ngày
    //@Scheduled(cron = "0 * * * * *")
    public void checkOverdueGoals() {
        log.info("[SavingGoalScheduler] Checking overdue goals...");

        // Bước 1: Tìm mục tiêu ACTIVE có endDate < today (đã quá hạn nhưng chưa OVERDUE)
        List<SavingGoal> overdueGoals = savingGoalRepository.findByGoalStatusAndEndDateBefore(
                GoalStatus.ACTIVE.getValue(), LocalDate.now());

        // Bước 2: Nếu không có → log và return
        if (overdueGoals.isEmpty()) {
            log.info("[SavingGoalScheduler] No overdue goals found.");
            return;
        }

        // Bước 3: Xử lý từng mục tiêu trong transaction riêng biệt
        for (SavingGoal goal : overdueGoals) {
            try {
                self.processOverdueGoal(goal); // self-injection cho @Transactional(REQUIRES_NEW)
            } catch (Exception e) {
                log.error("[SavingGoalScheduler] Error processing goal id={}: {}", goal.getId(), e.getMessage());
            }
        }

        log.info("[SavingGoalScheduler] Processed {} overdue goals.", overdueGoals.size());
    }

    /**
     * Xử lý 1 mục tiêu quá hạn: cập nhật status + gửi thông báo.
     *
     * → NotificationMessages.savingOverdue()
     *   Thông báo: Title="Mục tiêu quá hạn ⚠️"
     *   Content="Mục tiêu tiết kiệm \"Mua xe máy SH\" đã quá hạn nhưng vẫn còn thiếu 45.000.000 ₫. Bạn có muốn gia hạn?"
     *
     * Bảo mật: Dùng goal.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processOverdueGoal(SavingGoal goal) {
        // Bước 1: Cập nhật trạng thái ACTIVE → OVERDUE
        goal.setGoalStatus(GoalStatus.OVERDUE.getValue());
        savingGoalRepository.save(goal);

        // Bước 2: Tính số tiền còn thiếu = targetAmount - currentAmount
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remaining.compareTo(BigDecimal.ZERO) < 0) remaining = BigDecimal.ZERO; // Tránh số âm

        // Bước 3: Gửi thông báo — NotificationMessages.savingOverdue()
        //   → Title="Mục tiêu quá hạn ⚠️"
        //   → Content="Mục tiêu tiết kiệm \"Mua xe máy SH\" đã quá hạn nhưng vẫn còn thiếu 45.000.000 ₫. Bạn có muốn gia hạn?"
        NotificationContent msg = NotificationMessages.savingOverdue(goal.getGoalName(), remaining);
        notificationService.createNotification(
                goal.getAccount(),                       // Bảo mật: chỉ chủ mục tiêu nhận
                msg.title(), msg.content(),
                NotificationType.SAVING,                 // type = 2 (SAVING)
                goal.getId().longValue(),                 // related_id = goal.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );
        log.info("[SavingGoalScheduler] Goal id={} '{}' → OVERDUE.", goal.getId(), goal.getGoalName());
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 2 — Nhắc mục tiêu sắp đến hạn (8:00 AM mỗi ngày)
    // Lý do 8h sáng: Gửi nhắc nhở khi user mở app buổi sáng,
    // cùng khung giờ với BudgetScheduler.checkBudgets(), DebtScheduler.checkDebtReminders(),
    // EventScheduler.remindUpcomingEvents().
    // ══════════════════════════════════════════════════════════════════════

    /**
     * JOB 2: Nhắc các mục tiêu sắp đến hạn (còn <= 7 ngày).
     * Chạy lúc 8:00 AM mỗi ngày.
     *
     * → NotificationMessages.savingNearDeadline()
     *   Thông báo tạo ra: Title="Nhắc mục tiêu ⏰"
     *   Content="Mục tiêu \"Mua nhẫn cưới\" sắp đến hạn (30/11/2026). Còn 5 ngày và 15.000.000 ₫ nữa để hoàn thành!"
     */
    @Scheduled(cron = "0 0 8 * * ?") // 8:00 AM mỗi ngày
    //@Scheduled(cron = "0 * * * * *")
    public void remindNearDeadlineGoals() {
        log.info("[SavingGoalScheduler] Checking goals near deadline...");

        LocalDate today    = LocalDate.now();
        LocalDate deadline = today.plusDays(NEAR_DEADLINE_DAYS); // Mốc: today + 7 ngày

        // Bước 1: Tìm mục tiêu ACTIVE có endDate nằm trong khoảng today → today+7
        List<SavingGoal> nearGoals = savingGoalRepository
                .findByGoalStatusAndEndDateBetween(GoalStatus.ACTIVE.getValue(), today, deadline);

        // Bước 2: Gửi nhắc nhở cho từng mục tiêu (chỉ nếu còn thiếu tiền)
        for (SavingGoal goal : nearGoals) {
            try {
                // Tính số ngày còn lại = endDate - today
                int daysLeft = (int) java.time.temporal.ChronoUnit.DAYS.between(today, goal.getEndDate());
                // Tính số tiền còn thiếu = targetAmount - currentAmount
                BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) continue; // Đã đủ tiền → bỏ qua

                // Gửi thông báo — NotificationMessages.savingNearDeadline()
                //   → Title="Nhắc mục tiêu ⏰"
                //   → Content="Mục tiêu \"Mua nhẫn cưới\" sắp đến hạn (30/11/2026). Còn 5 ngày và 15.000.000 ₫ nữa để hoàn thành!"
                NotificationContent msg = NotificationMessages.savingNearDeadline(
                        goal.getGoalName(), daysLeft, goal.getEndDate(), remaining);
                notificationService.createNotification(
                        goal.getAccount(),               // Bảo mật: chỉ chủ mục tiêu nhận
                        msg.title(), msg.content(),
                        NotificationType.SAVING,         // type = 2 (SAVING)
                        goal.getId().longValue(),         // related_id = goal.id (để Flutter navigate)
                        null                              // scheduledTime = null → gửi ngay
                );

                log.info("[SavingGoalScheduler] Reminded goal id={} '{}' with {} days remaining.",
                        goal.getId(), goal.getGoalName(), daysLeft);
            } catch (Exception e) {
                log.error("[SavingGoalScheduler] Error reminding goal id={}: {}", goal.getId(), e.getMessage());
            }
        }
    }
}
