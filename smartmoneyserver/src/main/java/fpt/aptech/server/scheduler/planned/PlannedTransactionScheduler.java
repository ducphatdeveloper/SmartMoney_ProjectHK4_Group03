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

    // [1] Chạy hàng ngày lúc 1h sáng (0 0 1 = hàng ngày 01:00:00)
    @Scheduled(cron = "0 0 1 * * *")
    public void processDailyPlanned() {
        log.info("[PlannedScheduler] Bắt đầu quét giao dịch định kỳ và hóa đơn...");
        runCheck();
    }

    // [2] Trigger thủ công để test
    public void checkNow() {
        log.info("[PlannedScheduler] Chạy thủ công...");
        runCheck();
    }

    // [3] Logic chính: quét Recurring + Bills đến hạn hôm nay
    private void runCheck() {
        LocalDate today = LocalDate.now();
        int processedRecurring = 0;
        int processedBills     = 0;

        // Quét Giao dịch định kỳ đến hạn hôm nay (active=true)
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

        // Quét Hóa đơn đến hạn hôm nay (active=true)
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

    // [4] Xử lý Giao dịch định kỳ: Tạo Transaction + tính kỳ sau + gửi thông báo
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processRecurring(PlannedTransaction planned, LocalDate today) {
        // Bước 1: Check xem đã chạy hôm nay chưa (tránh duplicate)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Giao dịch định kỳ id={} đã xử lý hôm nay, bỏ qua.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Giao dịch định kỳ id={} đang tạm dừng, bỏ qua.", planned.getId());
            return;
        }

        // Bước 3: [LOGIC V2] Check Hết Hạn (EXPIRED)
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            log.warn("[PlannedScheduler] Giao dịch định kỳ id={} đã hết hạn ngày {}, nhưng vẫn active. Bỏ qua.",
                    planned.getId(), planned.getEndDate());
            return;
        }

        // Bước 4: Tạo Transaction từ Planned
        plannedService.createTransactionFromPlanned(planned);

        // Bước 5: Gửi thông báo xác nhận
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

        // Bước 6: Cập nhật lịch: lastExecutedAt, nextDueDate
        planned.setLastExecutedAt(today);
        LocalDate nextDue = plannedService.calculateNextDueDate(planned, planned.getNextDueDate());
        planned.setNextDueDate(nextDue);

        // Bước 7: Kiểm tra kết thúc (nếu nextDueDate vượt endDate → active=false)
        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false);
            log.info("[PlannedScheduler] Giao dịch định kỳ id={} đã kết thúc.", planned.getId());
        }

        plannedRepo.save(planned);
    }

    // [5] Xử lý Hóa đơn: Gửi notification nhắc + tính kỳ sau (KHÔNG tự tạo Transaction)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processBill(PlannedTransaction planned, LocalDate today) {
        // Bước 1: Check xem đã chạy hôm nay chưa (tránh nhắc lặp)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Hóa đơn id={} đã nhắc hôm nay, bỏ qua.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Hóa đơn id={} đang tạm dừng, bỏ qua.", planned.getId());
            return;
        }

        // Bước 3: [LOGIC V2] Check Hết Hạn (EXPIRED)
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            log.warn("[PlannedScheduler] Hóa đơn id={} đã hết hạn ngày {}, nhưng vẫn active. Không gửi thông báo nhắc nhở.",
                    planned.getId(), planned.getEndDate());
            return;
        }

        // Bước 4: Gửi thông báo nhắc user trả tiền
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

        // Bước 5: Cập nhật lịch: lastExecutedAt, nextDueDate
        planned.setLastExecutedAt(today);
        LocalDate nextDue = plannedService.calculateNextDueDate(planned, planned.getNextDueDate());
        planned.setNextDueDate(nextDue);

        // Bước 6: [YEU CAU CUA USER] KHONG TU DONG DEACTIVATE HOA DON KHI HET HAN.
        // User muon tu tay bam hoan tat.
        // if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
        //     planned.setActive(false);
        //     log.info("[PlannedScheduler] Hóa đơn id={} đã kết thúc.", planned.getId());
        // }

        plannedRepo.save(planned);
    }
}
