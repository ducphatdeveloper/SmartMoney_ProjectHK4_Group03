package fpt.aptech.server.scheduler.reminder;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Scheduler nhắc nhở chung (không thuộc module cụ thể).
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — dailyRecordReminder():  21:00 mỗi tối    → Nhắc user chưa ghi chép giao dịch hôm nay
 *   JOB 2 — weeklyDigest():         20:00 Chủ nhật    → Tổng kết chi tiêu tuần
 * ────────────────────────────────────────────────────────────────────────
 * Lý do phân khung giờ:
 *   - 21h tối: Cuối ngày nhắc user ghi chép (đủ muộn để user đã chi tiêu xong trong ngày)
 *   - 20h Chủ nhật: Tổng kết tuần vào cuối tuần, cùng buổi tối với WalletScheduler(20:00)
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *   1. dailyRecordReminder() → "Nhắc ghi chép 📝" — nhắc user chưa ghi giao dịch hôm nay
 *   2. weeklyDigest()        → "Tổng kết tuần 📊" — tổng chi tuần + top danh mục
 *
 * Bảo mật: Mỗi thông báo gắn acc (Account) → chỉ đúng user nhận được.
 * NotificationType: REMINDER (9), related_id: null
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ReminderScheduler {

    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final NotificationService notificationService;

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Nhắc ghi chép hàng ngày (21:00 mỗi tối)
    // Lý do 21h tối: Cuối ngày nhắc user ghi chép chi tiêu, đủ muộn để user
    // đã hoàn thành hầu hết giao dịch trong ngày. Nếu sớm hơn (VD 18h)
    // thì user có thể chưa chi tiêu xong → nhắc sớm không hiệu quả.
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Quét tất cả user active (chưa bị khóa).
     * Ai chưa có giao dịch nào hôm nay → gửi nhắc nhở ghi chép.
     *
     * → NotificationMessages.dailyRecordReminder()
     *   Thông báo tạo ra: Title="Nhắc ghi chép 📝"
     *   Content="Bạn chưa ghi chép chi tiêu hôm nay! Hãy dành 2 phút cập nhật sổ chi tiêu."
     */
    @Scheduled(cron = "0 0 21 * * ?") // 21:00 mỗi tối
    public void dailyRecordReminder() {
        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();           // 00:00:00 hôm nay
        LocalDateTime endOfDay = today.plusDays(1).atStartOfDay(); // 00:00:00 ngày mai (exclusive)

        log.info("[ReminderScheduler] Kiểm tra user chưa ghi chép hôm nay...");

        // Bước 1: Lấy tất cả account active (chưa bị khóa)
        List<Account> allActive = accountRepository.findAllActiveAccounts();

        // Bước 2: Lấy acc_id đã ghi giao dịch hôm nay → dùng Set cho O(1) lookup
        List<Integer> usersWithTxList = transactionRepository
                .findAccountIdsWithTransactionToday(startOfDay, endOfDay);
        Set<Integer> usersWithTx = usersWithTxList.stream().collect(Collectors.toSet());

        // Bước 3: Gửi nhắc nhở cho user chưa ghi chép
        int count = 0;
        for (Account acc : allActive) {
            if (!usersWithTx.contains(acc.getId())) { // User KHÔNG có giao dịch hôm nay
                try {
                    // Tạo thông báo — NotificationMessages.dailyRecordReminder()
                    //   → Title="Nhắc ghi chép 📝"
                    //   → Content="Bạn chưa ghi chép chi tiêu hôm nay! Hãy dành 2 phút cập nhật sổ chi tiêu."
                    NotificationContent msg = NotificationMessages.dailyRecordReminder();
                    notificationService.createNotification(
                            acc,                         // Bảo mật: chỉ user chưa ghi chép nhận
                            msg.title(), msg.content(),
                            NotificationType.REMINDER,   // type = 9 (REMINDER)
                            null,                         // related_id = null (không liên kết đối tượng cụ thể)
                            null                          // scheduledTime = null → gửi ngay
                    );
                    count++;
                } catch (Exception e) {
                    log.error("[ReminderScheduler] Lỗi nhắc user id={}: {}", acc.getId(), e.getMessage());
                }
            }
        }

        log.info("[ReminderScheduler] Đã nhắc {} user ghi chép. ({} user đã ghi chép hôm nay)",
                count, usersWithTx.size());
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 2 — Tổng kết tuần (Chủ nhật 20:00)
    // Lý do 20h Chủ nhật: Cuối tuần user có thời gian review chi tiêu,
    // cùng khung giờ buổi tối với WalletScheduler.checkAbnormalActivity(20:00 hàng ngày).
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Tính tổng chi tiêu 7 ngày qua cho mỗi user có giao dịch.
     * Lấy top danh mục chi nhiều nhất → gửi weeklyDigest().
     *
     * → NotificationMessages.weeklyDigest()
     *   Thông báo tạo ra: Title="Tổng kết tuần 📊"
     *   Content="Tuần này bạn đã chi 2.350.000 ₫. Danh mục chi nhiều nhất: Ăn uống (1.200.000 ₫)."
     */
    @Scheduled(cron = "0 0 20 * * SUN") // 20:00 Chủ nhật mỗi tuần
    public void weeklyDigest() {
        LocalDate today = LocalDate.now();
        LocalDateTime weekStart = today.minusDays(6).atStartOfDay();  // 7 ngày trước (inclusive)
        LocalDateTime weekEnd = today.atTime(23, 59, 59);             // Cuối ngày hôm nay

        log.info("[ReminderScheduler] Tạo tổng kết tuần ({} → {})...", weekStart.toLocalDate(), today);

        // Bước 1: Lấy tất cả account active
        List<Account> allActive = accountRepository.findAllActiveAccounts();
        int sentCount = 0;

        // Bước 2: Duyệt từng user, tính tổng chi + top danh mục
        for (Account acc : allActive) {
            try {
                // Bước 2.1: Tính tổng chi tuần (chỉ expense, không tính income)
                BigDecimal totalSpent = transactionRepository
                        .sumExpenseByDateRange(acc.getId(), weekStart, weekEnd);

                // Nếu không chi gì → bỏ qua (không gửi tổng kết rỗng)
                if (totalSpent == null || totalSpent.compareTo(BigDecimal.ZERO) == 0) {
                    continue;
                }

                // Bước 2.2: Lấy top danh mục chi nhiều nhất (kết quả: [categoryName, totalAmount])
                List<Object[]> topCategories = transactionRepository
                        .findTopExpenseCategoryByDateRange(acc.getId(), weekStart, weekEnd);

                if (topCategories.isEmpty()) {
                    continue; // Không có danh mục → bỏ qua
                }

                String topName = (String) topCategories.get(0)[0];        // Tên danh mục top 1
                BigDecimal topAmount = (BigDecimal) topCategories.get(0)[1]; // Số tiền top 1

                // Bước 2.3: Gửi thông báo tổng kết — NotificationMessages.weeklyDigest()
                //   → Title="Tổng kết tuần 📊"
                //   → Content="Tuần này bạn đã chi 2.350.000 ₫. Danh mục chi nhiều nhất: Ăn uống (1.200.000 ₫)."
                NotificationContent msg = NotificationMessages.weeklyDigest(
                        totalSpent, topName, topAmount);
                notificationService.createNotification(
                        acc,                             // Bảo mật: chỉ đúng user nhận
                        msg.title(), msg.content(),
                        NotificationType.REMINDER,       // type = 9 (REMINDER)
                        null,                             // related_id = null (không liên kết đối tượng cụ thể)
                        null                              // scheduledTime = null → gửi ngay
                );
                sentCount++;
            } catch (Exception e) {
                log.error("[ReminderScheduler] Lỗi tổng kết tuần cho user id={}: {}", acc.getId(), e.getMessage());
            }
        }

        log.info("[ReminderScheduler] Đã gửi tổng kết tuần cho {} user.", sentCount);
    }
}

