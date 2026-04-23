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
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

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

    // Anti-spam: ghi nhớ planned ID đã gửi notification thiếu tiền trong ngày (in-memory, reset mỗi ngày)
    private final Map<Integer, LocalDate> insufficientBalanceNotifiedMap = new ConcurrentHashMap<>();

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Xử lý giao dịch định kỳ + hóa đơn (1:00 AM mỗi ngày)
    // Lý do 1h sáng: Xử lý nền khi hệ thống ít tải, tạo transaction + nhắc bill
    // trước khi user thức dậy. Cùng khung giờ với BudgetScheduler.renewRecurringBudgets(),
    // SavingGoalScheduler.checkOverdueGoals(), EventScheduler.autoCompleteEvents().
    // ══════════════════════════════════════════════════════════════════════

    // [1] Chạy hàng ngày lúc 1h sáng (0 0 1 = hàng ngày 01:00:00)
    @Scheduled(cron = "0 0 1 * * *") // 1:00 AM mỗi ngày
    public void processDailyPlanned() {
        log.info("[PlannedScheduler] Starting scan for recurring transactions and bills...");
        runCheck();
    }

    // [2] Trigger thủ công để test (không có cron — gọi từ API hoặc test)
    public void checkNow() {
        log.info("[PlannedScheduler] Manual run...");
        runCheck();
    }

    // [3] Logic chính: quét Recurring + Bills đến hạn hôm nay
    private void runCheck() {
        LocalDate today = LocalDate.now();
        // Dọn notification anti-spam map (xóa entry cũ hơn hôm nay)
        insufficientBalanceNotifiedMap.entrySet().removeIf(e -> e.getValue().isBefore(today));
        int processedRecurring = 0; // Đếm số giao dịch định kỳ đã xử lý
        int processedBills     = 0; // Đếm số hóa đơn đã nhắc

        // Bước 1: Quét Giao dịch định kỳ đến hạn hôm nay (active=true, nextDueDate=today)
        List<PlannedTransaction> recurringList = plannedRepo.findRecurringDueToday(today);
        log.info("[PlannedScheduler] Found {} recurring transactions due today.", recurringList.size());
        for (PlannedTransaction planned : recurringList) {
            try {
                self.processRecurring(planned, today); // self-injection cho @Transactional(REQUIRES_NEW)
                processedRecurring++;
            } catch (Exception e) {
                // [FIX-LOG-STACKTRACE] Thêm `e` cuối cùng để log cả stack trace, không chỉ message
                log.error("[PlannedScheduler] Error in recurring transaction id={}: {}", planned.getId(), e.getMessage(), e);
            }
        }

        // Bước 2: Quét Hóa đơn đến hạn hôm nay (active=true, nextDueDate=today)
        List<PlannedTransaction> billsList = plannedRepo.findBillsDueToday(today);
        log.info("[PlannedScheduler] Found {} bills due today.", billsList.size());
        for (PlannedTransaction planned : billsList) {
            try {
                self.processBill(planned, today); // self-injection cho @Transactional(REQUIRES_NEW)
                processedBills++;
            } catch (Exception e) {
                // [FIX-LOG-STACKTRACE] Thêm `e` cuối cùng để log cả stack trace
                log.error("[PlannedScheduler] Error in bill id={}: {}", planned.getId(), e.getMessage(), e);
            }
        }

        log.info("[PlannedScheduler] Completed. Recurring: {} | Bills: {}", processedRecurring, processedBills);
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
        // ══════════════════════════════════════════════════════════════════
        // [FIX-DETACHED-ENTITY] Re-fetch planned trong REQUIRES_NEW transaction
        // BUG CŨ: planned được load ở runCheck() (transaction repo tự quản),
        //   khi processRecurring chạy REQUIRES_NEW → planned + wallet/category/account/debt
        //   đều bị DETACHED → persist() Transaction mới tham chiếu entity detached
        //   → Hibernate 6 ném PersistentObjectException: "detached entity passed to persist"
        //   → Exception bị catch im lặng → KHÔNG tạo giao dịch, KHÔNG deactivate.
        // FIX: Re-fetch planned từ DB trong transaction mới → tất cả entity đều MANAGED.
        // ══════════════════════════════════════════════════════════════════
        planned = plannedRepo.findById(planned.getId()).orElse(null);
        if (planned == null) {
            log.warn("[PlannedScheduler] Recurring transaction not found after re-fetch, skipping.");
            return;
        }

        // Bước 1: Check đã chạy hôm nay chưa (tránh duplicate nếu scheduler chạy lại)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Recurring transaction id={} already processed today, skipping.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Recurring transaction id={} is paused, skipping.", planned.getId());
            return;
        }

        // Bước 3: [FIX-ZOMBIE-EXPIRED] Check Hết Hạn (EXPIRED) — endDate đã qua nhưng vẫn active
        // BUG CŨ: chỉ log rồi return → planned giữ active=true mãi mãi → scheduler tìm thấy mỗi ngày
        //   nhưng không xử lý, không deactivate → trạng thái "zombie" vĩnh viễn.
        // FIX: set active=false + save → dọn dẹp planned hết hạn.
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            planned.setActive(false);
            planned.setLastExecutedAt(today);
            plannedRepo.save(planned);
            log.info("[PlannedScheduler] Recurring transaction id={} expired on {} → auto deactivate.",
                    planned.getId(), planned.getEndDate());
            return;
        }

        // Bước 4: Xác định loại giao dịch sớm (dùng cho cả pre-check balance và notification)
        boolean isIncome = Boolean.TRUE.equals(planned.getCategory().getCtgType()); // true=Thu, false=Chi
        // Nhãn hiển thị: ưu tiên note, fallback về tên danh mục
        String label = planned.getNote() != null ? planned.getNote() : planned.getCategory().getCtgName();

        // Bước 5: [FIX-DEBT-PRECHECK] Kiểm tra khoản nợ liên kết đã hoàn thành chưa
        // Nếu debt đã finished=true TRƯỚC khi tạo transaction → deactivate luôn, không tạo GD thừa
        // Trường hợp: debt đã trả xong (bằng GD thủ công hoặc payBill) nhưng recurring vẫn active
        if (planned.getDebt() != null) {
            Debt preCheckDebt = debtRepo.findById(planned.getDebt().getId()).orElse(null);
            if (preCheckDebt != null && Boolean.TRUE.equals(preCheckDebt.getFinished())) {
                planned.setActive(false);
                planned.setLastExecutedAt(today);
                plannedRepo.save(planned);
                log.info("[PlannedScheduler] Recurring transaction id={} linked to debt id={} completed → deactivate, not creating transaction.",
                        planned.getId(), preCheckDebt.getId());
                return; // Debt đã xong → không cần tạo transaction nữa
            }
        }

        // Bước 6: [PRE-CHECK SỐ DƯ] Chỉ áp dụng cho CHI tiêu (isIncome=false)
        // Kiểm tra ví đủ tiền TRƯỚC khi tạo transaction — nếu không đủ:
        //   → Gửi thông báo cảnh báo cho user (anti-spam: 1 lần/ngày qua in-memory map)
        //   → KHÔNG advance nextDueDate, KHÔNG set lastExecutedAt
        //   → Scheduler sẽ RETRY kỳ này vào lần chạy tiếp khi ví đủ tiền
        // [FIX-RETRY] BUG CŨ: advance nextDueDate khi thiếu tiền → kỳ bị bỏ qua vĩnh viễn,
        //   user nạp tiền sau cũng không có giao dịch retro. FIX: giữ nguyên nextDueDate.
        if (!isIncome) {
            Wallet wallet = planned.getWallet(); // Lazy load trong @Transactional
            if (wallet.getBalance().compareTo(planned.getAmount()) < 0) {

                // [6.1] Anti-spam: chỉ gửi notification thiếu tiền 1 lần/ngày (in-memory map)
                LocalDate lastNotified = insufficientBalanceNotifiedMap.get(planned.getId());
                boolean shouldNotify = lastNotified == null || lastNotified.isBefore(today);

                if (shouldNotify) {
                    NotificationContent insufficientMsg = NotificationMessages.recurringInsufficientBalance(
                            label, planned.getAmount(), wallet.getWalletName(), wallet.getBalance());
                    notificationService.createNotification(
                            planned.getAccount(),
                            insufficientMsg.title(), insufficientMsg.content(),
                            NotificationType.REMINDER,
                            Long.valueOf(planned.getId()),
                            null
                    );
                    insufficientBalanceNotifiedMap.put(planned.getId(), today);
                } else {
                    log.debug("[PlannedScheduler] Anti-spam: Insufficient balance notification already sent for id={} today, skipping.", planned.getId());
                }

                // [6.2] KHÔNG advance nextDueDate, KHÔNG set lastExecutedAt
                // → Giữ nguyên nextDueDate để Scheduler retry kỳ này khi ví đủ tiền
                // → lastExecutedAt giữ nguyên để duplicate-check (Bước 1) không chặn retry
                log.warn("[PlannedScheduler] Recurring transaction id={} '{}' INSUFFICIENT BALANCE cycle {}: wallet '{}' has {} < needed {}. Keeping nextDueDate, will RETRY when sufficient funds.",
                        planned.getId(), label, planned.getNextDueDate(),
                        wallet.getWalletName(), wallet.getBalance(), planned.getAmount());
                return; // KHÔNG tạo transaction, KHÔNG advance — chờ retry
            }
        }

        // Bước 7: Tạo Transaction từ Planned (số dư đã đảm bảo đủ ở Bước 6)
        // createTransactionFromPlanned() xử lý: tạo Transaction + trừ ví + recalculate debt
        plannedService.createTransactionFromPlanned(planned);

        // Xóa anti-spam entry (nếu trước đó thiếu tiền → nay đã tạo GD thành công)
        insufficientBalanceNotifiedMap.remove(planned.getId());

        // Bước 7.5: [FIX-AUTODEACTIVATE-RECURRING] Kiểm tra nợ liên kết — nếu debt đã hoàn thành → deactivate recurring
        // Nếu recurring liên kết debt và debt vừa được kết thúc (do recalculateDebt() ở Bước 7)
        // → tự động deactivate recurring này
        if (planned.getDebt() != null) {
            Debt updatedDebt = debtRepo.findById(planned.getDebt().getId()).orElse(null);
            if (updatedDebt != null && Boolean.TRUE.equals(updatedDebt.getFinished())) {
                planned.setActive(false); // Debt đã trả xong → không cần tạo transaction nữa
                log.info("[PlannedScheduler] Giao dịch định kỳ id={} liên kết debt id={}. Debt đã hoàn thành → deactivate recurring.",
                        planned.getId(), updatedDebt.getId());
            }
        }

        // Bước 8: Gửi thông báo xác nhận thành công
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

        // Bước 9: [FIX-CATCHUP] Cập nhật lịch: lastExecutedAt = today, tính nextDueDate catch-up tới tương lai
        // BUG CŨ: chỉ tiến 1 kỳ → nếu nextDueDate cũ xa quá khứ, nextDueDate mới vẫn ở quá khứ
        //   VD: nextDueDate=01/03 + 1 tháng = 01/04, nhưng today=13/04 → 01/04 < 13/04 → kẹt!
        // FIX: vòng lặp tiến cho đến khi nextDueDate > today
        planned.setLastExecutedAt(today);
        LocalDate nextDue = plannedService.calculateNextDueDate(planned, planned.getNextDueDate());
        int safety = 0; // Giới hạn vòng lặp tránh infinite loop
        while (!nextDue.isAfter(today) && safety++ < 1000) {
            nextDue = plannedService.calculateNextDueDate(planned, nextDue);
        }
        planned.setNextDueDate(nextDue);

        // Bước 10: Kiểm tra kết thúc (nếu nextDueDate vượt endDate → active=false)
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
        // [FIX-DETACHED-ENTITY] Re-fetch planned trong REQUIRES_NEW transaction (giống processRecurring)
        planned = plannedRepo.findById(planned.getId()).orElse(null);
        if (planned == null) {
            log.warn("[PlannedScheduler] Bill not found after re-fetch, skipping.");
            return;
        }

        // Bước 1: Check xem đã nhắc hôm nay chưa (tránh spam nếu scheduler trigger lại trong ngày)
        if (planned.getLastExecutedAt() != null && planned.getLastExecutedAt().isEqual(today)) {
            log.debug("[PlannedScheduler] Bill id={} already reminded today, skipping.", planned.getId());
            return;
        }

        // Bước 2: Check active=true (nếu tạm dừng thì bỏ qua)
        if (!Boolean.TRUE.equals(planned.getActive())) {
            log.debug("[PlannedScheduler] Bill id={} is paused, skipping.", planned.getId());
            return;
        }

        // Bước 3: [FIX-ZOMBIE-EXPIRED] Check Hết Hạn (EXPIRED) — endDate đã qua nhưng vẫn active
        // BUG CŨ: chỉ log rồi return → bill giữ active=true mãi mãi → trạng thái "zombie".
        // FIX: set active=false + save → dọn dẹp bill hết hạn.
        if (planned.getEndDate() != null && planned.getEndDate().isBefore(today)) {
            planned.setActive(false);
            planned.setLastExecutedAt(today);
            plannedRepo.save(planned);
            log.info("[PlannedScheduler] Bill id={} expired on {} → auto deactivate.",
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
            log.info("[PlannedScheduler] Bill id={} OVERDUE {} days, sending reminder.", planned.getId(), daysOverdue);
        } else {
            // Hóa đơn đến hạn hôm nay
            msg = NotificationMessages.billDue(label, planned.getAmount());
            log.info("[PlannedScheduler] Bill id={} DUE TODAY, sending reminder.", planned.getId());
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
