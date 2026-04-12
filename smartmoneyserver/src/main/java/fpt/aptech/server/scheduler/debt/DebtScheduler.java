package fpt.aptech.server.scheduler.debt;

import fpt.aptech.server.entity.Debt;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.DebtRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Scheduler nhắc nhở khoản nợ.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — checkDebtReminders():  8:00 AM mỗi ngày → Nhắc nợ tổng hợp (sớm + sắp hạn + quá hạn)
 * ────────────────────────────────────────────────────────────────────────
 * Lý do 8h sáng: Nhắc nợ vào buổi sáng khi user bắt đầu ngày mới, có thời gian xử lý tài chính.
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *   1. debtEarlyReminder()     → "Nhắc nợ sắp đến hạn 📋" / "Nhắc thu nợ sắp đến hạn 📋" — trước 10 ngày
 *   2. debtPayableReminder()   → "Nhắc khoản nợ 💸" — sắp đến hạn 0-3 ngày (cần trả)
 *   3. debtReceivableReminder()→ "Nhắc khoản thu 💰" — sắp đến hạn 0-3 ngày (cần thu)
 *   4. debtOverdue()           → "Khoản nợ quá hạn ⚠️" / "Khoản thu quá hạn ⚠️" — đã quá hạn
 *
 * Phân loại theo debt_type:
 *   debt_type = false (Đi vay / Cần trả) → isPayable = true
 *   debt_type = true  (Cho vay / Cần thu) → isPayable = false
 *
 * Bảo mật: Mỗi thông báo gắn debt.getAccount() → chỉ chủ sở hữu khoản nợ nhận được.
 * NotificationType: DEBT_LOAN (8), related_id = debt.id
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DebtScheduler {

    // Self-injection để dùng @Transactional(REQUIRES_NEW) cho từng debt riêng biệt
    @Autowired
    @Lazy
    private DebtScheduler self;

    private final DebtRepository debtRepository;
    private final NotificationService notificationService;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Kiểm tra nhắc nợ tổng hợp (8:00 AM mỗi ngày)
    // Lý do 8h sáng: Nhắc nợ vào buổi sáng khi user bắt đầu ngày mới.
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Chạy lúc 8:00 AM mỗi ngày.
     * Quét tất cả khoản nợ chưa xong (finished=false) có due_date.
     * Chia thành 3 nhóm: nhắc sớm (10 ngày), sắp hạn (0-3 ngày), quá hạn.
     */
    @Scheduled(cron = "0 0 8 * * ?") // 8:00 AM mỗi ngày
    public void checkDebtReminders() {
        LocalDate today = LocalDate.now();
        log.info("[DebtScheduler] Bắt đầu kiểm tra nhắc nợ...");

        int earlyCount   = 0; // Đếm số thông báo nhắc sớm
        int nearDueCount = 0; // Đếm số thông báo sắp hạn
        int overdueCount = 0; // Đếm số thông báo quá hạn

        // ── 1. Nhắc sớm trước 10 ngày (today+9 → today+11, chỉ bắt đúng mốc 10 ngày) ──
        LocalDateTime earlyFrom = today.plusDays(9).atStartOfDay();   // Cận dưới: 9 ngày sau
        LocalDateTime earlyTo   = today.plusDays(11).atStartOfDay();  // Cận trên: 11 ngày sau (exclusive)
        List<Debt> earlyDue = debtRepository.findActiveDebtsWithDueDateBetween(earlyFrom, earlyTo);
        for (Debt debt : earlyDue) {
            try {
                self.notifyDebtEarly(debt, today); // self-injection cho @Transactional(REQUIRES_NEW)
                earlyCount++;
            } catch (Exception e) {
                log.error("[DebtScheduler] Lỗi nhắc sớm khoản nợ id={}: {}", debt.getId(), e.getMessage());
            }
        }

        // ── 2. Nhắc khoản nợ sắp đến hạn (today → today+3 ngày) ──
        LocalDateTime nearFrom = today.atStartOfDay();               // Cận dưới: hôm nay
        LocalDateTime nearTo   = today.plusDays(4).atStartOfDay();   // Cận trên: 4 ngày sau (exclusive)
        List<Debt> nearDue = debtRepository.findActiveDebtsWithDueDateBetween(nearFrom, nearTo);
        for (Debt debt : nearDue) {
            try {
                self.notifyDebtNearDue(debt); // self-injection cho @Transactional(REQUIRES_NEW)
                nearDueCount++;
            } catch (Exception e) {
                log.error("[DebtScheduler] Lỗi nhắc khoản nợ id={}: {}", debt.getId(), e.getMessage());
            }
        }

        // ── 3. Nhắc khoản nợ đã quá hạn (due_date < today) ──
        LocalDateTime overdueThreshold = today.atStartOfDay(); // Mốc: đầu ngày hôm nay
        List<Debt> overdue = debtRepository.findOverdueDebts(overdueThreshold);
        for (Debt debt : overdue) {
            try {
                self.notifyDebtOverdue(debt); // self-injection cho @Transactional(REQUIRES_NEW)
                overdueCount++;
            } catch (Exception e) {
                log.error("[DebtScheduler] Lỗi nhắc nợ quá hạn id={}: {}", debt.getId(), e.getMessage());
            }
        }

        log.info("[DebtScheduler] Hoàn tất. Nhắc sớm 10 ngày: {} | Sắp đến hạn: {} | Quá hạn: {}",
                earlyCount, nearDueCount, overdueCount);
    }

    /**
     * Gửi thông báo nhắc sớm (10 ngày trước hạn) cho 1 khoản nợ.
     *
     * → NotificationMessages.debtEarlyReminder()
     *   Nếu isPayable=true (Đi vay):
     *     Thông báo: Title="Nhắc nợ sắp đến hạn 📋"
     *     Content="Bạn còn nợ Anh Tuấn số tiền 5.000.000 ₫. Còn 10 ngày nữa đến hạn (25/04/2026). Hãy chuẩn bị!"
     *   Nếu isPayable=false (Cho vay):
     *     Thông báo: Title="Nhắc thu nợ sắp đến hạn 📋"
     *     Content="Khoản cho Anh Minh vay 3.000.000 ₫. Còn 10 ngày nữa đến hạn (25/04/2026). Hãy chuẩn bị!"
     *
     * Bảo mật: Dùng debt.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyDebtEarly(Debt debt, LocalDate today) {
        // Bước 1: Xác định loại nợ — debt_type=false → Đi vay → isPayable=true (cần trả)
        boolean isPayable = !debt.getDebtType();
        LocalDate dueDate = debt.getDueDate().toLocalDate(); // Chuyển DateTime → Date

        // Bước 2: Tính số ngày còn lại từ hôm nay đến dueDate
        int daysLeft = (int) java.time.temporal.ChronoUnit.DAYS.between(today, dueDate);

        // Bước 3: Tạo nội dung thông báo từ NotificationMessages
        NotificationContent msg = NotificationMessages.debtEarlyReminder(
                debt.getPersonName(), debt.getRemainAmount(), dueDate, daysLeft, isPayable);

        // Bước 4: Gửi thông báo — gắn debt.getAccount() để đảm bảo đúng người nhận
        notificationService.createNotification(
                debt.getAccount(),                       // Bảo mật: chỉ chủ khoản nợ nhận
                msg.title(), msg.content(),
                NotificationType.DEBT_LOAN,              // type = 8 (DEBT_LOAN)
                Long.valueOf(debt.getId()),               // related_id = debt.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.debug("[DebtScheduler] Đã nhắc sớm khoản nợ id={} '{}' ({}), hạn: {}, còn {} ngày",
                debt.getId(), debt.getPersonName(),
                isPayable ? "Cần trả" : "Cần thu", dueDate, daysLeft);
    }

    /**
     * Gửi thông báo nhắc nhở sắp đến hạn (0-3 ngày) cho 1 khoản nợ.
     *
     * → Nếu isPayable=true: NotificationMessages.debtPayableReminder()
     *   Thông báo: Title="Nhắc khoản nợ 💸"
     *   Content="Bạn còn nợ Anh Tuấn số tiền 5.000.000 ₫. Hạn thanh toán: 15/04/2026."
     *
     * → Nếu isPayable=false: NotificationMessages.debtReceivableReminder()
     *   Thông báo: Title="Nhắc khoản thu 💰"
     *   Content="Khoản cho Anh Minh vay 3.000.000 ₫ đến hạn thu vào 15/04/2026. Hãy liên hệ!"
     *
     * Bảo mật: Dùng debt.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyDebtNearDue(Debt debt) {
        // Bước 1: Xác định loại nợ — debt_type=false → Đi vay → isPayable=true (cần trả)
        boolean isPayable = !debt.getDebtType();
        LocalDate dueDate = debt.getDueDate().toLocalDate(); // Chuyển DateTime → Date

        // Bước 2: Tạo nội dung thông báo theo loại nợ (payable hoặc receivable)
        NotificationContent msg = isPayable
                ? NotificationMessages.debtPayableReminder(
                        debt.getPersonName(), debt.getRemainAmount(), dueDate)
                : NotificationMessages.debtReceivableReminder(
                        debt.getPersonName(), debt.getRemainAmount(), dueDate);

        // Bước 3: Gửi thông báo — gắn debt.getAccount() để đảm bảo đúng người nhận
        notificationService.createNotification(
                debt.getAccount(),                       // Bảo mật: chỉ chủ khoản nợ nhận
                msg.title(), msg.content(),
                NotificationType.DEBT_LOAN,              // type = 8 (DEBT_LOAN)
                Long.valueOf(debt.getId()),               // related_id = debt.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.debug("[DebtScheduler] Đã nhắc khoản nợ sắp hạn id={} '{}' ({}), hạn: {}",
                debt.getId(), debt.getPersonName(),
                isPayable ? "Cần trả" : "Cần thu", dueDate);
    }

    /**
     * Gửi thông báo nhắc nhở khoản nợ đã quá hạn cho 1 khoản nợ.
     *
     * → NotificationMessages.debtOverdue()
     *   Nếu isPayable=true (Đi vay):
     *     Thông báo: Title="Khoản nợ quá hạn ⚠️"
     *     Content="Bạn còn nợ Anh Tuấn số tiền 5.000.000 ₫ đã quá hạn từ 01/04/2026. Hãy xử lý ngay!"
     *   Nếu isPayable=false (Cho vay):
     *     Thông báo: Title="Khoản thu quá hạn ⚠️"
     *     Content="Khoản cho Anh Minh vay 3.000.000 ₫ đã quá hạn từ 01/04/2026. Hãy xử lý ngay!"
     *
     * Bảo mật: Dùng debt.getAccount() → chỉ chủ sở hữu nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void notifyDebtOverdue(Debt debt) {
        // Bước 1: Xác định loại nợ — debt_type=false → Đi vay → isPayable=true (cần trả)
        boolean isPayable = !debt.getDebtType();
        LocalDate dueDate = debt.getDueDate().toLocalDate(); // Chuyển DateTime → Date

        // Bước 2: Tạo nội dung thông báo quá hạn
        NotificationContent msg = NotificationMessages.debtOverdue(
                debt.getPersonName(), debt.getRemainAmount(), dueDate, isPayable);

        // Bước 3: Gửi thông báo — gắn debt.getAccount() để đảm bảo đúng người nhận
        notificationService.createNotification(
                debt.getAccount(),                       // Bảo mật: chỉ chủ khoản nợ nhận
                msg.title(), msg.content(),
                NotificationType.DEBT_LOAN,              // type = 8 (DEBT_LOAN)
                Long.valueOf(debt.getId()),               // related_id = debt.id (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );

        log.debug("[DebtScheduler] Đã nhắc nợ quá hạn id={} '{}' ({}), hạn: {}",
                debt.getId(), debt.getPersonName(),
                isPayable ? "Cần trả" : "Cần thu", dueDate);
    }
}
