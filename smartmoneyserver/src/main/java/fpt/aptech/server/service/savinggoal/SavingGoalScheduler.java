package fpt.aptech.server.service.savinggoal;

import fpt.aptech.server.entity.SavingGoal;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.savinggoal.GoalStatus;
import fpt.aptech.server.repos.SavingGoalRepository;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

// @Component: Đánh dấu class này là một "Bean" để Spring Boot quản lý.
@Component
// @RequiredArgsConstructor: Tự động tạo constructor cho các trường `final`, không cần @Autowired.
@RequiredArgsConstructor
// @Slf4j: Tự động tạo biến `log` để ghi log ra console, không cần khai báo thủ công.
@Slf4j
public class SavingGoalScheduler {

    private final SavingGoalRepository savingGoalRepository;
    private final NotificationService notificationService;

    /**
     * Tác vụ chạy ngầm mỗi ngày vào lúc 1h sáng.
     * Mục đích:
     *   - Tìm các mục tiêu đang ACTIVE nhưng đã quá ngày kết thúc (endDate).
     *   - Chuyển trạng thái sang OVERDUE (Quá hạn).
     *   - Gửi thông báo nhắc nhở cho người dùng.
     */

    // Cron "0 0 1 * * ?": Chạy đúng lúc 01:00:00 AM mỗi ngày.
    @Scheduled(cron = "0 0 1 * * ?")

    // Test: Chạy ngay 3 giây sau khi server start dùng để test
    //@Scheduled(initialDelay = 3000, fixedDelay = Long.MAX_VALUE)

    // @Transactional: Bọc toàn bộ method trong 1 transaction.
    //   - Nếu KHÔNG có lỗi → COMMIT: tất cả thay đổi được lưu vào DB.
    //   - Nếu CÓ lỗi       → ROLLBACK: toàn bộ thay đổi bị hủy, DB trở về trạng thái ban đầu.
    //   - rollbackFor = Exception.class: rollback cả checked Exception (mặc định chỉ rollback RuntimeException).
    @Transactional(rollbackFor = Exception.class)
    public void checkOverdueGoals() {
        log.info("Scheduler bắt đầu: Kiểm tra các mục tiêu tiết kiệm quá hạn...");

        // Bước 1: Tìm tất cả các mục tiêu đang ACTIVE và có ngày kết thúc trước hôm nay.
        // Hibernate load các entity vào Persistence Context và "chụp ảnh" trạng thái ban đầu.
        List<SavingGoal> overdueGoals = savingGoalRepository.findByGoalStatusAndEndDateBefore(
                GoalStatus.ACTIVE.getValue(),
                LocalDate.now()
        );

        // Bước 2: Nếu không tìm thấy mục tiêu nào thỏa điều kiện → kết thúc sớm, không làm gì thêm.
        if (overdueGoals.isEmpty()) {
            log.info("Không có mục tiêu nào cần chuyển sang trạng thái quá hạn. Kết thúc tác vụ.");
            return;
        }

        log.info("Tìm thấy {} mục tiêu quá hạn. Bắt đầu xử lý...", overdueGoals.size());

        // Bước 3: Lặp qua từng mục tiêu quá hạn để xử lý.
        for (SavingGoal goal : overdueGoals) {

            // Bước 3.1: Cập nhật trạng thái sang OVERDUE.
            // Hibernate tự động đánh dấu entity này là "dirty" (đã thay đổi).
            goal.setGoalStatus(GoalStatus.OVERDUE.getValue());

            // Bước 3.2: Tạo thông báo đẩy cho người dùng biết mục tiêu đã quá hạn.
            notificationService.createNotification(
                    goal.getAccount(),
                    "Mục tiêu quá hạn",
                    "Mục tiêu tiết kiệm '" + goal.getGoalName() + "' đã quá hạn nhưng chưa hoàn thành.",
                    NotificationType.SAVING,
                    goal.getId().longValue(),
                    null // null = gửi thông báo ngay lập tức, không hẹn giờ.
            );

            // Bước 3.3: Ghi log chi tiết từng mục tiêu đã được xử lý.
            log.info("  -> Đã xử lý mục tiêu ID: {}, Tên: '{}'", goal.getId(), goal.getGoalName());
        }

        // Bước 4: Lưu tất cả thay đổi vào database.
        // Lưu ý: @Transactional + Hibernate dirty checking đã tự động UPDATE các entity bị thay đổi
        // khi transaction commit. Gọi saveAll() ở đây để code tường minh, dễ đọc cho người mới.
        savingGoalRepository.saveAll(overdueGoals);

        log.info("Hoàn tất cập nhật {} mục tiêu quá hạn.", overdueGoals.size());
    }
}