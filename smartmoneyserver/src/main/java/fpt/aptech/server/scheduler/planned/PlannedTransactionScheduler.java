package fpt.aptech.server.scheduler.planned;

import fpt.aptech.server.entity.PlannedTransaction;
import fpt.aptech.server.entity.Debt;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.PlannedTransactionRepository;
import fpt.aptech.server.repos.DebtRepository;
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
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Scheduler xử lý giao dịch định kỳ và hóa đơn.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — processDailyPlanned():  1:00 AM mỗi ngày → Quét + xử lý Recurring + Bills đến hạn
 * ────────────────────────────────────────────────────────────────────────
 * Lý do 1h sáng: Xử lý nền khi hệ thống ít tải. Giao dịch định kỳ và hóa đơn được tạo/nhắc
 * trước khi user thức dậy, đảm bảo dữ liệu nhất quán khi user mở app buổi sáng.
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *   1. recurringExecuted() → "Giao dịch định kỳ đã thực hiện 🔄" — auto tạo transaction thành công
 *   2. billDue()           → "Hóa đơn đến hạn! 📋" — nhắc user trả hóa đơn (KHÔNG auto tạo transaction)
 *
 * Bảo mật: Mỗi thông báo gắn planned.getAccount() → chỉ chủ sở hữu nhận được.
 * NotificationType: REMINDER (9), related_id = planned.id
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PlannedTransactionScheduler {

    @Autowired    // FIX: Dùng Field Injection để tránh Circular Dependency trong Constructor do @RequiredArgsConstructor inject tất cả field final
    @Lazy
    private PlannedTransactionScheduler self; //bỏ final

    private final PlannedTransactionRepository plannedRepo;
    private final DebtRepository debtRepo;
    private final PlannedTransactionServiceImpl plannedService;
    private final NotificationService notificationService;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Xử lý giao dịch định kỳ + hóa đơn (1:00 AM mỗi ngày)
    // Lý do 1h sáng: Xử lý nền khi hệ thống ít tải, tạo transaction + nhắc bill
    // trước khi user thức dậy. Cùng khung giờ với BudgetScheduler.renewRecurringBudgets(),
    // SavingGoalScheduler.checkOverdueGoals(), EventScheduler.autoCompleteEvents().
    // ══════════════════════════════════════════════════════════════════════

    // [1] Chạy hàng ngày lúc 1h sáng (0 0 1 = hàng ngày 01:00:00)
    @Scheduled(cron = "0 0 1 * * *") // 1:00 AM mỗi ngày
    public void processDailyPlanned() {
        log.info("[PlannedScheduler] Bắt đầu quét giao dịch định kỳ và hóa đơn...");
        runCheck();
    }

    // [2] Trigger thủ công để test (không có cron — gọi từ API hoặc test)
    public void checkNow() {
        log.info("[PlannedScheduler] Chạy thủ công...");
        runCheck();
    }

    // [3] Logic chính: quét Recurring + Bills đến hạn hôm nay
    private void runCheck() {
        LocalDate today = LocalDate.now();
        int processedRecurring = 0; // Đếm số giao dịch định kỳ đã xử lý
        int processedBills     = 0; // Đếm số hóa đơn đã nhắc

        // Bước 1: Quét Giao dịch định kỳ đến hạn hôm nay (active=true, nextDueDate=today)
        List<PlannedTransaction> recurringList = plannedRepo.findRecurringDueToday(today);
        log.info("[PlannedScheduler] Tìm thấy {} Giao dịch định kỳ đến hạn.", recurringList.size());
        for (PlannedTransaction planned : recurringList) {
            try {
                self.processRecurring(planned, today); // self-injection cho @Transactional(REQUIRES_NEW)
                processedRecurring++;
            } catch (Exception e) {
                log.error("[PlannedScheduler] Lỗi Giao dịch định kỳ id={}: {}", planned.getId(), e.getMessage());
            }
        }

        // Bước 2: Quét Hóa đơn đến hạn hôm nay (active=true, nextDueDate=today)
        List<PlannedTransaction> billsList = plannedRepo.findBillsDueToday(today);
        log.info("[PlannedScheduler] Tìm thấy {} Hóa đơn đến hạn.", billsList.size());
        for (PlannedTransaction planned : billsList) {
            try {
                self.processBill(planned, today); // self-injection cho @Transactional(REQUIRES_NEW)
                processedBills++;
            } catch (Exception e) {
                log.error("[PlannedScheduler] Lỗi Hóa đơn id={}: {}", planned.getId(), e.getMessage());
            }
        }

        log.info("[PlannedScheduler] Hoàn tất. Giao dịch định kỳ: {} | Hóa đơn: {}", processedRecurring, processedBills);
    }

    /**
     * [4] Xử lý Giao dịch định kỳ: kiểm tra số dư → Tạo Transaction → cập nhật lịch → gửi thông báo.
     *
     * Trường hợp số dư KHÔNG ĐỦ (CHI tiêu):
     *   → NotificationMessages.recurringInsufficientBalance()
     *   Thông báo: Title="Giao dịch định kỳ bị bỏ qua ⚠️"
     *   Content="Giao dịch định kỳ \"Tiền nhà\" không thể thực hiện: Ví \"MoMo\" chỉ còn 50.000 ₫, cần 5.000.000 ₫. Kỳ này đã bị bỏ qua..."
     *   → Tiến nextDueDate sang kỳ sau (KHÔNG tạo transaction, KHÔNG retry vô hạn)
     *
     * Trường hợp THÀNH CÔNG:
     *   → NotificationMessages.recurringExecuted()
     *   Thông báo: Title="Giao dịch định kỳ đã thực hiện 🔄"
     *   Content="Giao dịch định kỳ \"Tiền nhà tháng 4\" đã tự động chi 5.000.000 ₫."
     *   (hoặc "... đã tự động thu ..." nếu isIncome=true)
     *
     * Bảo mật: Dùng planned.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processRecurring(PlannedTransaction planned, LocalDate today) {
        // Bước 1: Check đã chạy hôm nay chưa (tránh duplicate nếu scheduler chạy lại)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Giao dịch định kỳ id={} đã xử lý hôm nay, bỏ qua.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Giao dịch định kỳ id={} đang tạm dừng, bỏ qua.", planned.getId());
            return;
        }

        // Bước 3: [LOGIC V2] Check Hết Hạn (EXPIRED) — endDate đã qua nhưng vẫn active
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            log.warn("[PlannedScheduler] Giao dịch định kỳ id={} đã hết hạn ngày {}, nhưng vẫn active. Bỏ qua.",
                    planned.getId(), planned.getEndDate());
            return;
        }

        // Bước 4: Xác định loại giao dịch sớm (dùng cho cả pre-check balance và notification)
        boolean isIncome = Boolean.TRUE.equals(planned.getCategory().getCtgType()); // true=Thu, false=Chi
        // Nhãn hiển thị: ưu tiên note, fallback về tên danh mục
        String label = planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName();

        // Bước 5: [PRE-CHECK SỐ DƯ] Chỉ áp dụng cho CHI tiêu (isIncome=false)
        // Kiểm tra ví đủ tiền TRƯỚC khi tạo transaction — nếu không đủ:
        //   → Gửi thông báo cảnh báo cho user
        //   → Tiến nextDueDate sang kỳ sau (bỏ qua kỳ này hoàn toàn)
        //   → KHÔNG tạo transaction
        // Lý do tiến lịch thay vì retry: nếu không tiến → scheduler retry mỗi ngày → spam notification
        if (!isIncome) {
            Wallet wallet = planned.getWallet(); // Lazy load trong @Transactional
            if (wallet.getBalance().compareTo(planned.getAmount()) < 0) {

                // [5.1] Gửi thông báo số dư không đủ
                // → NotificationMessages.recurringInsufficientBalance()
                //   Title="Giao dịch định kỳ bị bỏ qua ⚠️"
                //   Content="Giao dịch định kỳ \"Tiền nhà\" không thể thực hiện: Ví \"MoMo\" chỉ còn 50.000 ₫,
                //            cần 5.000.000 ₫. Kỳ này đã bị bỏ qua — vui lòng nạp thêm tiền vào ví."
                NotificationContent insufficientMsg = NotificationMessages.recurringInsufficientBalance(
                        label, planned.getAmount(), wallet.getWalletName(), wallet.getBalance());
                notificationService.createNotification(
                        planned.getAccount(),              // Bảo mật: chỉ chủ giao dịch nhận
                        insufficientMsg.title(), insufficientMsg.content(),
                        NotificationType.REMINDER,         // type = 9 (REMINDER)
                        Long.valueOf(planned.getId()),      // related_id = planned.id (để Flutter navigate)
                        null                               // scheduledTime = null → gửi ngay
                );

                // [5.2] Tiến lịch: đánh dấu đã xử lý hôm nay + nhảy sang kỳ sau
                // Lý do dùng getNextDueDate() (ngày đang hạn) làm điểm xuất phát tính kỳ tiếp
                LocalDate skippedDue = planned.getNextDueDate(); // Lưu ngày bị bỏ qua để log
                LocalDate nextDue = plannedService.calculateNextDueDate(planned, skippedDue);
                planned.setLastExecutedAt(today);  // Đánh dấu đã "xử lý" hôm nay (dù bỏ qua)
                planned.setNextDueDate(nextDue);   // Tiến sang kỳ tiếp theo

                // [5.3] Kiểm tra kết thúc nếu nextDueDate vượt endDate
                if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
                    planned.setActive(false);
                    log.info("[PlannedScheduler] Giao dịch định kỳ id={} đã kết thúc (kỳ {} bị bỏ qua do số dư không đủ).",
                            planned.getId(), skippedDue);
                }

                plannedRepo.save(planned); // Lưu trạng thái tiến lịch vào DB

                log.warn("[PlannedScheduler] Giao dịch định kỳ id={} '{}' BỎ QUA kỳ {}: ví '{}' còn {} < cần {}. Kỳ tiếp: {}",
                        planned.getId(), label, skippedDue,
                        wallet.getWalletName(), wallet.getBalance(), planned.getAmount(), nextDue);
                return; // KHÔNG tạo transaction — kết thúc sớm
            }
        }

        // Bước 6: Tạo Transaction từ Planned (số dư đã đảm bảo đủ ở Bước 5)
        // createTransactionFromPlanned() xử lý: tạo Transaction + trừ ví + recalculate debt
        plannedService.createTransactionFromPlanned(planned);

        // Bước 6.5: [FIX-AUTODEACTIVATE-RECURRING] Kiểm tra nợ liên kết — nếu debt đã hoàn thành → deactivate recurring
        // Nếu recurring liên kết debt và debt vừa được kết thúc (do recalculateDebt() ở Bước 6)
        // → tự động deactivate recurring này
        if (planned.getDebt() != null) {
            Debt updatedDebt = debtRepo.findById(planned.getDebt().getId()).orElse(null);
            if (updatedDebt != null && Boolean.TRUE.equals(updatedDebt.getFinished())) {
                planned.setActive(false); // Debt đã trả xong → không cần tạo transaction nữa
                log.info("[PlannedScheduler] Giao dịch định kỳ id={} liên kết debt id={}. Debt đã hoàn thành → deactivate recurring.",
                        planned.getId(), updatedDebt.getId());
            }
        }

        // Bước 7: Gửi thông báo xác nhận thành công
        // → NotificationMessages.recurringExecuted()
        //   Title="Giao dịch định kỳ đã thực hiện 🔄"
        //   Content="Giao dịch định kỳ \"Tiền nhà\" đã tự động chi 5.000.000 ₫."  (Chi)
        //   Content="Giao dịch định kỳ \"Lương tháng 4\" đã tự động thu 15.000.000 ₫." (Thu)
        NotificationContent msg = NotificationMessages.recurringExecuted(
                label,               // Nhãn giao dịch (note hoặc tên danh mục)
                planned.getAmount(), // Số tiền
                isIncome             // true=thu nhập, false=chi tiêu
        );
        notificationService.createNotification(
                planned.getAccount(),                    // Bảo mật: chỉ chủ giao dịch nhận
                msg.title(), msg.content(),
                NotificationType.REMINDER,               // type = 9 (REMINDER)
                Long.valueOf(planned.getId()),            // related_id = planned.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.info("[PlannedScheduler] Đã tạo Transaction cho Giao dịch định kỳ id={} '{}', amount={}.",
                planned.getId(), label, planned.getAmount());

        // Bước 8: Cập nhật lịch: lastExecutedAt = today, tính nextDueDate kỳ sau
        planned.setLastExecutedAt(today);
        LocalDate nextDue = plannedService.calculateNextDueDate(planned, planned.getNextDueDate());
        planned.setNextDueDate(nextDue);

        // Bước 9: Kiểm tra kết thúc (nếu nextDueDate vượt endDate → active=false)
        if (planned.getEndDate() != null && nextDue.isAfter(planned.getEndDate())) {
            planned.setActive(false); // Hết kỳ → deactivate
            log.info("[PlannedScheduler] Giao dịch định kỳ id={} đã kết thúc.", planned.getId());
        }

        plannedRepo.save(planned); // Lưu trạng thái mới vào DB
    }

    /**
     * [5] Xử lý Hóa đơn: CHỈ gửi notification nhắc (KHÔNG tự tạo Transaction, KHÔNG advance nextDueDate).
     *
     * ⚠️ QUAN TRỌNG — Phân biệt rõ Bills vs Recurring:
     *   - Recurring (plan_type=2): Scheduler TỰ ĐỘNG tạo Transaction + advance nextDueDate
     *   - Bills    (plan_type=1): Scheduler CHỈ nhắc nhở. nextDueDate chỉ tiến khi USER bấm "Trả tiền" (payBill)
     *
     * Lý do KHÔNG advance nextDueDate ở đây:
     *   Nếu advance trước khi user trả → payBill() sẽ từ chối vì today.isBefore(nextDueDate)
     *   → User không thể thanh toán, bill trông như "đã tự động trả" dù không có transaction nào.
     *
     * lastExecutedAt được set để:
     *   - Tránh spam reminder trong CÙNG ngày (nếu scheduler trigger nhiều lần)
     *   - Khi overdue: mỗi ngày vẫn nhắc 1 lần cho đến khi user trả
     *
     * Notification:
     *   - Đúng hạn hôm nay → billDue()   : "Hóa đơn đến hạn! 📋"
     *   - Quá hạn X ngày  → billOverdue() : "Hóa đơn quá hạn! ⏰ — Quá hạn X ngày"
     *
     * Bảo mật: Dùng planned.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processBill(PlannedTransaction planned, LocalDate today) {
        // Bước 1: Check xem đã nhắc hôm nay chưa (tránh spam nếu scheduler trigger lại trong ngày)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Hóa đơn id={} đã nhắc hôm nay, bỏ qua.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Hóa đơn id={} đang tạm dừng, bỏ qua.", planned.getId());
            return;
        }

        // Bước 3: [LOGIC V2] Check Hết Hạn (EXPIRED) — endDate đã qua nhưng vẫn active
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            log.warn("[PlannedScheduler] Hóa đơn id={} đã hết hạn ngày {}, nhưng vẫn active. Không gửi thông báo.",
                    planned.getId(), planned.getEndDate());
            return;
        }

        // Bước 4: Gửi thông báo nhắc user trả tiền (phân loại đúng hạn vs quá hạn)
        String label = planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName();
        NotificationContent msg;
        if (planned.getNextDueDate().isBefore(today)) {
            // Hóa đơn quá hạn — tính số ngày đã trễ để hiện cho user
            long daysOverdue = ChronoUnit.DAYS.between(planned.getNextDueDate(), today);
            msg = NotificationMessages.billOverdue(label, planned.getAmount(), daysOverdue);
            log.info("[PlannedScheduler] Hóa đơn id={} QUÁ HẠN {} ngày, gửi nhắc nhở.", planned.getId(), daysOverdue);
        } else {
            // Hóa đơn đến hạn hôm nay
            msg = NotificationMessages.billDue(label, planned.getAmount());
            log.info("[PlannedScheduler] Hóa đơn id={} ĐẾN HẠN hôm nay, gửi nhắc nhở.", planned.getId());
        }

        notificationService.createNotification(
                planned.getAccount(),                    // Bảo mật: chỉ chủ hóa đơn nhận
                msg.title(), msg.content(),
                NotificationType.REMINDER,               // type = 9 (REMINDER)
                Long.valueOf(planned.getId()),            // related_id = planned.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        // Bước 5: Chỉ đánh dấu đã nhắc hôm nay — KHÔNG advance nextDueDate
        // ⚠️ nextDueDate CHỈ được tiến khi user thực sự bấm "Trả tiền" (payBill)
        //    Nếu advance ở đây → user bị block bởi check today.isBefore(nextDueDate) trong payBill()
        //    → bill trông như "đã tự động trả" dù không có transaction nào (BUG)
        planned.setLastExecutedAt(today); // Đánh dấu đã nhắc hôm nay (tránh spam cùng ngày)
        // planned.setNextDueDate(nextDue); ← ĐÃ XÓA: không được advance ở đây

        plannedRepo.save(planned);
    }
}
