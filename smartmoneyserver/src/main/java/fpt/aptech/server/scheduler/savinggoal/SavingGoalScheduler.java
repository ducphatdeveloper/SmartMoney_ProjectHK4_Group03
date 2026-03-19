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

    /**
     * JOB 1: Chuyển ACTIVE → OVERDUE nếu đã quá endDate.
     * Chạy lúc 1:00 AM mỗi ngày.
     */
    @Scheduled(cron = "0 0 1 * * ?")
    public void checkOverdueGoals() {
        log.info("[SavingGoalScheduler] Kiểm tra mục tiêu quá hạn...");

        List<SavingGoal> overdueGoals = savingGoalRepository.findByGoalStatusAndEndDateBefore(
                GoalStatus.ACTIVE.getValue(), LocalDate.now());

        if (overdueGoals.isEmpty()) {
            log.info("[SavingGoalScheduler] Không có mục tiêu quá hạn.");
            return;
        }

        for (SavingGoal goal : overdueGoals) {
            try {
                self.processOverdueGoal(goal);
            } catch (Exception e) {
                log.error("[SavingGoalScheduler] Lỗi mục tiêu id={}: {}", goal.getId(), e.getMessage());
            }
        }

        log.info("[SavingGoalScheduler] Đã xử lý {} mục tiêu quá hạn.", overdueGoals.size());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processOverdueGoal(SavingGoal goal) {
        // Bước 1: Cập nhật trạng thái
        goal.setGoalStatus(GoalStatus.OVERDUE.getValue());
        savingGoalRepository.save(goal);

        // Bước 2: Tính số tiền còn thiếu
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remaining.compareTo(BigDecimal.ZERO) < 0) remaining = BigDecimal.ZERO;

        // Bước 3: Gửi thông báo
        NotificationContent msg = NotificationMessages.savingOverdue(goal.getGoalName(), remaining);
        notificationService.createNotification(
                goal.getAccount(),
                msg.title(), msg.content(),
                NotificationType.SAVING,
                goal.getId().longValue(),
                null
        );
        log.info("[SavingGoalScheduler] Mục tiêu id={} '{}' → QUÁ HẠN (OVERDUE).", goal.getId(), goal.getGoalName());
    }

    /**
     * JOB 2: Nhắc các mục tiêu sắp đến hạn (còn <= 7 ngày).
     * Chạy lúc 8:00 AM mỗi ngày.
     */
    @Scheduled(cron = "0 0 8 * * ?")
    public void remindNearDeadlineGoals() {
        log.info("[SavingGoalScheduler] Kiểm tra mục tiêu sắp đến hạn...");

        LocalDate today    = LocalDate.now();
        LocalDate deadline = today.plusDays(NEAR_DEADLINE_DAYS);

        List<SavingGoal> nearGoals = savingGoalRepository
                .findByGoalStatusAndEndDateBetween(GoalStatus.ACTIVE.getValue(), today, deadline);

        for (SavingGoal goal : nearGoals) {
            try {
                int daysLeft = (int) java.time.temporal.ChronoUnit.DAYS.between(today, goal.getEndDate());
                BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
                if (remaining.compareTo(BigDecimal.ZERO) <= 0) continue; // Đã đủ tiền → bỏ qua

                NotificationContent msg = NotificationMessages.savingNearDeadline(
                        goal.getGoalName(), daysLeft, goal.getEndDate(), remaining);
                notificationService.createNotification(
                        goal.getAccount(),
                        msg.title(), msg.content(),
                        NotificationType.SAVING,
                        goal.getId().longValue(),
                        null
                );

                log.info("[SavingGoalScheduler] Đã nhắc mục tiêu id={} '{}' còn {} ngày.",
                        goal.getId(), goal.getGoalName(), daysLeft);
            } catch (Exception e) {
                log.error("[SavingGoalScheduler] Lỗi khi nhắc mục tiêu id={}: {}", goal.getId(), e.getMessage());
            }
        }
    }
}
