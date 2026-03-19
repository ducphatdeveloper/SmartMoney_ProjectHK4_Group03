package fpt.aptech.server.scheduler.planned;

import fpt.aptech.server.entity.PlannedTransaction;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.PlannedTransactionRepository;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationService;
import fpt.aptech.server.service.planned.PlannedTransactionServiceImpl;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.context.annotation.Lazy;

import java.time.LocalDate;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class PlannedTransactionScheduler {

    @Autowired    // FIX: Dùng Field Injection để tránh Circular Dependency trong Constructor do @RequiredArgsConstructor inject tất cả field final
    @Lazy
    private PlannedTransactionScheduler self; //bỏ final

    private final PlannedTransactionRepository plannedRepo;
    private final PlannedTransactionServiceImpl plannedService;
    private final NotificationService notificationService;

    @Scheduled(cron = "0 0 2 * * *")
    public void processDailyPlanned() {
        log.info("[PlannedScheduler] Bắt đầu quét giao dịch định kỳ và hóa đơn...");
        runCheck();
    }

    public void checkNow() {
        log.info("[PlannedScheduler] Chạy thủ công...");
        runCheck();
    }

    private void runCheck() {
        LocalDate today = LocalDate.now();
        int processedRecurring = 0;
        int processedBills     = 0;

        List<PlannedTransaction> recurringList = plannedRepo.findRecurringDueToday(today);
        log.info("[PlannedScheduler] Tìm thấy {} Giao dịch định kỳ đến hạn.", recurringList.size());
        for (PlannedTransaction planned : recurringList) {
            try {
                self.processRecurring(planned, today);
                processedRecurring++;
            } catch (Exception e) {
                log.error("[PlannedScheduler] Lỗi Giao dịch định kỳ id={}: {}", planned.getId(), e.getMessage());
            }
        }

        List<PlannedTransaction> billsList = plannedRepo.findBillsDueToday(today);
        log.info("[PlannedScheduler] Tìm thấy {} Hóa đơn đến hạn.", billsList.size());
        for (PlannedTransaction planned : billsList) {
            try {
                self.processBill(planned, today);
                processedBills++;
            } catch (Exception e) {
                log.error("[PlannedScheduler] Lỗi Hóa đơn id={}: {}", planned.getId(), e.getMessage());
            }
        }

        log.info("[PlannedScheduler] Hoàn tất. Giao dịch định kỳ: {} | Hóa đơn: {}", processedRecurring, processedBills);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processRecurring(PlannedTransaction planned, LocalDate today) {
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Giao dịch định kỳ id={} đã xử lý hôm nay, bỏ qua.", planned.getId());
            return;
        }

        plannedService.createTransactionFromPlanned(planned);

        // Gửi thông báo xác nhận giao dịch định kỳ đã chạy
        boolean isIncome = Boolean.TRUE.equals(planned.getCategory().getCtgType());
        NotificationContent msg = NotificationMessages.recurringExecuted(
                planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName(),
                planned.getAmount(),
                isIncome
        );
        notificationService.createNotification(
                planned.getAccount(),
                msg.title(), msg.content(),
                NotificationType.REMINDER,
                Long.valueOf(planned.getId()),
                null
        );

        log.info("[PlannedScheduler] Đã tạo Transaction cho Giao dịch định kỳ id={}, amount={}.",
                planned.getId(), planned.getAmount());

        planned.setLastExecutedAt(today);
        LocalDate nextDue = plannedService.calculateNextDueDate(planned, today);
        planned.setNextDueDate(nextDue);

        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false);
            log.info("[PlannedScheduler] Giao dịch định kỳ id={} đã kết thúc.", planned.getId());
        }

        plannedRepo.save(planned);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processBill(PlannedTransaction planned, LocalDate today) {
        // Bill chỉ gửi notification nhắc — KHÔNG tự tạo Transaction
        NotificationContent msg = NotificationMessages.billDue(
                planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName(),
                planned.getAmount()
        );
        notificationService.createNotification(
                planned.getAccount(),
                msg.title(), msg.content(),
                NotificationType.REMINDER,
                Long.valueOf(planned.getId()),
                null
        );

        log.info("[PlannedScheduler] Đã nhắc Hóa đơn id={}, amount={}.",
                planned.getId(), planned.getAmount());

        LocalDate nextDue = plannedService.calculateNextDueDate(planned, today);
        planned.setNextDueDate(nextDue);

        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false);
            log.info("[PlannedScheduler] Hóa đơn id={} đã kết thúc.", planned.getId());
        }

        plannedRepo.save(planned);
    }
}
