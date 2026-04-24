package fpt.aptech.server.scheduler.transaction;

import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;

/**
 * Scheduler quản lý thông báo giao dịch hàng ngày.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — analyzeDailySpending():       20:00 mỗi tối → So sánh chi tiêu hôm nay vs hôm qua
 *   JOB 2 — dailyTransactionDigest():     21:00 mỗi tối → Tổng kết chi tiêu hàng ngày
 *   JOB 3 — remindNoTransaction():        10:00 mỗi sáng → Nhắc nếu không có giao dịch trong 3 ngày
 *   JOB 4 — analyzeWeeklyTrend():         8:00 AM mỗi ngày → Phân tích xu hướng chi tiêu tuần
 *   JOB 5 — remindNoTransactionToday():   21:00 mỗi tối → Nhắc nếu chưa ghi chép hôm nay (gom từ ReminderScheduler)
 *   JOB 6 — weeklyDigest():               20:00 Chủ nhật → Tổng kết chi tiêu tuần (gom từ ReminderScheduler)
 *   JOB 7 — checkAbnormalTransactionCount(): 20:00 mỗi tối → Phát hiện chi tiêu bất thường theo số lượng (>10 giao dịch, gom từ WalletScheduler)
 *   JOB 8 — analyzeMonthlyTrend():        1:00 AM ngày 1 → Phân tích xu hướng chi tiêu tháng
 *   JOB 9 — monthlyDigest():              1:00 AM ngày 1 → Tổng kết chi tiêu tháng
 * ────────────────────────────────────────────────────────────────────────
 * Lý do phân khung giờ:
 *   - 8h sáng: Phân tích xu hướng khi user mở app buổi sáng (cùng khung với DebtScheduler, SavingGoalScheduler)
 *   - 10h sáng: Nhắc ghi chép giao dịch (sau khi user đã bắt đầu ngày)
 *   - 20h tối: So sánh chi tiêu ngày + kiểm tra bất thường (cùng khung với WalletScheduler cũ)
 *   - 21h tối: Tổng kết chi tiêu + nhắc ghi chép (cùng khung với ReminderScheduler cũ)
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *
 *   1. dailySpendingSpike()  → "Chi tiêu hôm nay tăng cao ⚠️" — nếu tăng quá 30% so với hôm qua (JOB 1)
 *      Content: "Chi tiêu hôm nay tăng cao ⚠️: Hôm nay bạn đã chi 2.000.000 ₫, tăng 50% so với hôm qua (1.333.333 ₫)."
 *
 *   2. dailyDigest()         → "Tổng kết chi tiêu hôm nay 📊" — tổng chi + top category (JOB 2)
 *      Content: "Tổng kết chi tiêu hôm nay 📊: Hôm nay bạn đã chi 2.000.000 ₫. Top: Ăn uống (1.000.000 ₫), Di chuyển (500.000 ₫)."
 *
 *   3. noTransactionReminder() → "Nhắc ghi chép giao dịch 📝" — nếu không có giao dịch trong 3 ngày (JOB 3)
 *      Content: "Nhắc ghi chép giao dịch 📝: Bạn chưa ghi chép giao dịch trong 3 ngày qua. Hãy ghi chép ngay để quản lý tài chính hiệu quả."
 *
 *   4. weeklyTrendAlert()    → "Xu hướng chi tiêu tuần 📈" — nếu tăng quá 30% so với tuần trước (JOB 4)
 *      Content: "Xu hướng chi tiêu tuần 📈: Tuần này bạn đã chi 10.000.000 ₫, tăng 50% so với tuần trước (6.666.667 ₫)."
 *
 *   5. dailyRecordReminder() → "Nhắc ghi chép 📝" — nếu chưa ghi chép hôm nay (JOB 5, gom từ ReminderScheduler)
 *      Content: "Nhắc ghi chép 📝: Bạn chưa ghi chép giao dịch hôm nay. Hãy ghi chép ngay để quản lý tài chính hiệu quả."
 *
 *   6. weeklyDigestMsg()     → "Tổng kết tuần 📊" — tổng chi tuần + top category (JOB 6, gom từ ReminderScheduler)
 *      Content: "Tổng kết tuần 📊: Tuần này bạn đã chi 15.000.000 ₫. Top: Ăn uống (6.000.000 ₫), Mua sắm (3.000.000 ₫)."
 *
 *   7. abnormalWalletActivity() → "Cảnh báo chi tiêu bất thường 🚩" — cho user (JOB 7, >10 giao dịch, gom từ WalletScheduler)
 *      Content: "Cảnh báo chi tiêu bất thường 🚩: Ví 'Ví chính' của bạn có 15 giao dịch chi trong 24h qua với tổng số tiền 2.000.000 ₫."
 *
 *   8. adminWalletRiskAlert() → "Cảnh báo rủi ro ví người dùng 🚨" — cho admin (JOB 7, gom từ WalletScheduler)
 *      Content: "Cảnh báo rủi ro ví người dùng 🚨: User 'user@example.com' có ví 'Ví chính' với 15 giao dịch chi trong 24h qua."
 *
 *   9. monthlyTrendAlert()  → "Xu hướng chi tiêu tháng 📈" — nếu tăng quá 30% so với tháng trước (JOB 8)
 *      Content: "Xu hướng chi tiêu tháng 📈: Tháng này bạn đã chi 30.000.000 ₫, tăng 50% so với tháng trước (20.000.000 ₫)."
 *
 *   10. monthlyDigest()     → "Tổng kết chi tiêu tháng 📊" — tổng chi tháng + top category (JOB 9)
 *      Content: "Tổng kết chi tiêu tháng 📊: Tháng này bạn đã chi 30.000.000 ₫. Top: Ăn uống (12.000.000 ₫), Mua sắm (6.000.000 ₫), Di chuyển (4.000.000 ₫)."
 *
 * Bảo mật: Mỗi thông báo gắn account → chỉ đúng user nhận được.
 * NotificationType: TRANSACTION (1), related_id: null
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TransactionScheduler {

    private final TransactionRepository transactionRepository;
    private final AccountRepository accountRepository;
    private final WalletRepository walletRepository;
    private final NotificationService notificationService;

    // [1] Ngưỡng cảnh báo
    private static final double SPIKE_THRESHOLD = 0.3;   // Ngưỡng tăng chi tiêu hôm nay vs hôm qua
    private static final double WEEKLY_INCREASE_THRESHOLD = 0.3; // Ngưỡng tăng chi tiêu tuần này vs tuần trước
    private static final int NO_TRANSACTION_DAYS = 3;     // Số ngày không có giao dịch để nhắc
    private static final long ABNORMAL_TX_THRESHOLD = 10; // Số giao dịch chi bất thường trong 24h (ngưỡng Việt Nam)

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — So sánh chi tiêu hôm nay vs hôm qua (20:00 mỗi tối)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 20 * * *")
    @Transactional
    public void analyzeDailySpending() {
        log.info("[TransactionScheduler] Bắt đầu phân tích chi tiêu hàng ngày");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDate yesterday = today.minusDays(1); // Ngày hôm qua

        // [1.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        // [1.2] Vòng lặp qua tất cả account để phân tích chi tiêu
        for (Account account : accounts) {
            try {
                analyzeDailySpendingForAccount(account, today, yesterday);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi phân tích chi tiêu cho account id={}: {}", account.getId(), e.getMessage());
            }
        }
    }

    /**
     * [1.1] Phân tích chi tiêu cho một account cụ thể.
     * @param account - Account cần phân tích
     * @param today - Ngày hôm nay
     * @param yesterday - Ngày hôm qua
     */
    private void analyzeDailySpendingForAccount(Account account, LocalDate today, LocalDate yesterday) {
        // [1.1.1] Tính tổng chi hôm nay
        LocalDateTime todayStart = today.atStartOfDay(); // Bắt đầu ngày hôm nay
        LocalDateTime todayEnd = today.atTime(23, 59, 59); // Kết thúc ngày hôm nay
        BigDecimal todaySpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), todayStart, todayEnd);

        // [1.1.2] Tính tổng chi hôm qua
        LocalDateTime yesterdayStart = yesterday.atStartOfDay(); // Bắt đầu ngày hôm qua
        LocalDateTime yesterdayEnd = yesterday.atTime(23, 59, 59); // Kết thúc ngày hôm qua
        BigDecimal yesterdaySpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), yesterdayStart, yesterdayEnd);

        // [1.1.3] Nếu hôm qua không chi gì → không so sánh
        if (yesterdaySpent.compareTo(BigDecimal.ZERO) == 0) {
            return; // Trả về không làm gì
        }

        // [1.1.4] Tính % tăng
        BigDecimal increaseRate = todaySpent.subtract(yesterdaySpent)
                .divide(yesterdaySpent, 2, RoundingMode.HALF_UP);

        // [1.1.5] Nếu tăng quá ngưỡng → cảnh báo
        if (increaseRate.compareTo(BigDecimal.valueOf(SPIKE_THRESHOLD)) > 0) {
            NotificationContent msg = NotificationMessages.dailySpendingSpike(
                    todaySpent, yesterdaySpent, increaseRate);
            notificationService.createNotification(
                    account,
                    msg.title(),
                    msg.content(),
                    NotificationType.TRANSACTION,
                    null,
                    null
            );
            log.info("[TransactionScheduler] Đã gửi cảnh báo chi tiêu tăng cho account id={}", account.getId());
        }
        // [1.1.6] Trả về không làm gì nếu không tăng quá ngưỡng
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 2 — Tổng kết chi tiêu hàng ngày (21:00 mỗi tối)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 21 * * *")
    @Transactional
    public void dailyTransactionDigest() {
        log.info("[TransactionScheduler] Bắt đầu tổng kết chi tiêu hàng ngày");
        LocalDate today = LocalDate.now(); // Ngày hôm nay

        // [2.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        // [2.2] Vòng lặp qua tất cả account để tổng kết chi tiêu
        for (Account account : accounts) {
            try {
                dailyDigestForAccount(account, today);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi tổng kết chi tiêu cho account id={}: {}", account.getId(), e.getMessage());
            }
        }
    }

    /**
     * [2.1] Tổng kết chi tiêu cho một account cụ thể.
     * @param account - Account cần tổng kết
     * @param today - Ngày hôm nay
     */
    private void dailyDigestForAccount(Account account, LocalDate today) {
        LocalDateTime todayStart = today.atStartOfDay(); // Bắt đầu ngày hôm nay
        LocalDateTime todayEnd = today.atTime(23, 59, 59); // Kết thúc ngày hôm nay

        // [2.1.1] Tính tổng chi hôm nay
        BigDecimal todaySpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), todayStart, todayEnd);

        // [2.1.2] Nếu không có giao dịch → không gửi
        if (todaySpent.compareTo(BigDecimal.ZERO) == 0) {
            return; // Trả về không làm gì
        }

        // [2.1.3] Lấy top category chi nhiều nhất
        List<Object[]> topCategories = transactionRepository.findTopExpenseCategoriesForAccount(
                account.getId(), todayStart, todayEnd);

        // [2.1.4] Gửi thông báo tổng kết
        NotificationContent msg = NotificationMessages.dailyDigest(
                todaySpent, topCategories);
        notificationService.createNotification(
                account,
                msg.title(),
                msg.content(),
                NotificationType.TRANSACTION,
                null,
                null
        );
        log.info("[TransactionScheduler] Đã gửi tổng kết chi tiêu cho account id={}", account.getId());
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 3 — Nhắc nếu không có giao dịch trong 3 ngày (10:00 mỗi sáng)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 10 * * *")
    @Transactional
    public void remindNoTransaction() {
        log.info("[TransactionScheduler] Bắt đầu nhắc ghi chép giao dịch");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDate threeDaysAgo = today.minusDays(NO_TRANSACTION_DAYS); // 3 ngày trước

        // [3.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        // [3.2] Vòng lặp qua tất cả account để nhắc ghi chép
        for (Account account : accounts) {
            try {
                remindNoTransactionForAccount(account, threeDaysAgo);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi nhắc giao dịch cho account id={}: {}", account.getId(), e.getMessage());
            }
        }
    }

    /**
     * [3.1] Nhắc ghi chép cho một account cụ thể.
     * @param account - Account cần nhắc
     * @param threeDaysAgo - 3 ngày trước
     */
    private void remindNoTransactionForAccount(Account account, LocalDate threeDaysAgo) {
        LocalDateTime threeDaysAgoStart = threeDaysAgo.atStartOfDay(); // Bắt đầu 3 ngày trước
        LocalDateTime todayEnd = LocalDate.now().atTime(23, 59, 59); // Kết thúc ngày hôm nay

        // [3.1.1] Kiểm tra có giao dịch trong 3 ngày qua không
        Long transactionCount = transactionRepository.countTransactionsForAccountInPeriod(
                account.getId(), threeDaysAgoStart, todayEnd);

        // [3.1.2] Nếu không có giao dịch → nhắc
        if (transactionCount == 0) {
            NotificationContent msg = NotificationMessages.noTransactionReminder(NO_TRANSACTION_DAYS);
            notificationService.createNotification(
                    account,
                    msg.title(),
                    msg.content(),
                    NotificationType.TRANSACTION,
                    null,
                    null
            );
            log.info("[TransactionScheduler] Đã nhắc ghi chép cho account id={}", account.getId());
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 4 — Phân tích xu hướng chi tiêu tuần (8:00 AM mỗi ngày)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 8 * * *")
    @Transactional
    public void analyzeWeeklyTrend() {
        log.info("[TransactionScheduler] Bắt đầu phân tích xu hướng chi tiêu tuần");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDate thisWeekStart = today.minusDays(today.getDayOfWeek().getValue() - 1); // Thứ 2 tuần này
        LocalDate lastWeekStart = thisWeekStart.minusWeeks(1); // Thứ 2 tuần trước
        LocalDate lastWeekEnd = thisWeekStart.minusDays(1); // Chủ nhật tuần trước

        // [4.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        // [4.2] Vòng lặp qua tất cả account để phân tích xu hướng
        for (Account account : accounts) {
            try {
                analyzeWeeklyTrendForAccount(account, thisWeekStart, lastWeekStart, lastWeekEnd);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi phân tích xu hướng cho account id={}: {}", account.getId(), e.getMessage());
            }
        }
    }

    /**
     * [4.1] Phân tích xu hướng cho một account cụ thể.
     * @param account - Account cần phân tích
     * @param thisWeekStart - Bắt đầu tuần này
     * @param lastWeekStart - Bắt đầu tuần trước
     * @param lastWeekEnd - Kết thúc tuần trước
     */
    private void analyzeWeeklyTrendForAccount(Account account, LocalDate thisWeekStart, 
            LocalDate lastWeekStart, LocalDate lastWeekEnd) {
        // [4.1.1] Tính tổng chi tuần này
        LocalDateTime thisWeekStartDt = thisWeekStart.atStartOfDay(); // Bắt đầu tuần này
        LocalDateTime todayEnd = LocalDate.now().atTime(23, 59, 59); // Kết thúc ngày hôm nay
        BigDecimal thisWeekSpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), thisWeekStartDt, todayEnd);

        // [4.1.2] Tính tổng chi tuần trước
        LocalDateTime lastWeekStartDt = lastWeekStart.atStartOfDay(); // Bắt đầu tuần trước
        LocalDateTime lastWeekEndDt = lastWeekEnd.atTime(23, 59, 59); // Kết thúc tuần trước
        BigDecimal lastWeekSpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), lastWeekStartDt, lastWeekEndDt);

        // [4.1.3] Nếu tuần trước không chi gì → không so sánh
        if (lastWeekSpent.compareTo(BigDecimal.ZERO) == 0) {
            return; // Trả về không làm gì
        }

        // [4.1.4] Tính % tăng
        BigDecimal increaseRate = thisWeekSpent.subtract(lastWeekSpent)
                .divide(lastWeekSpent, 2, RoundingMode.HALF_UP);

        // [4.1.5] Nếu tăng quá ngưỡng → cảnh báo
        if (increaseRate.compareTo(BigDecimal.valueOf(WEEKLY_INCREASE_THRESHOLD)) > 0) {
            NotificationContent msg = NotificationMessages.weeklyTrendAlert(
                    thisWeekSpent, lastWeekSpent, increaseRate);
            notificationService.createNotification(
                    account,
                    msg.title(),
                    msg.content(),
                    NotificationType.TRANSACTION,
                    null,
                    null
            );
            log.info("[TransactionScheduler] Đã gửi cảnh báo xu hướng chi tiêu cho account id={}", account.getId());
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 5 — Nhắc nếu chưa ghi chép giao dịch hôm nay (21:00 mỗi tối) - GOM TỪ REMINDERSCHEDULER
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 21 * * *")
    @Transactional
    public void remindNoTransactionToday() {
        log.info("[TransactionScheduler] Checking users who haven't recorded transactions today...");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDateTime startOfDay = today.atStartOfDay(); // Bắt đầu ngày hôm nay
        LocalDateTime endOfDay = today.plusDays(1).atStartOfDay(); // Bắt đầu ngày mai

        // [5.1] Lấy tất cả account active
        List<Account> allActive = accountRepository.findAll();

        // [5.2] Lấy acc_id đã ghi giao dịch hôm nay → dùng Set cho O(1) lookup
        List<Integer> usersWithTxList = transactionRepository
                .findAccountIdsWithTransactionToday(startOfDay, endOfDay);
        Set<Integer> usersWithTx = new java.util.HashSet<>(usersWithTxList);

        // [5.3] Gửi nhắc nhở cho user chưa ghi chép
        int count = 0;
        for (Account acc : allActive) {
            if (!usersWithTx.contains(acc.getId())) { // Nếu user chưa ghi chép
                try {
                    NotificationContent msg = NotificationMessages.dailyRecordReminder();
                    notificationService.createNotification(
                            acc,
                            msg.title(),
                            msg.content(),
                            NotificationType.TRANSACTION,
                            null,
                            null
                    );
                    count++;
                } catch (Exception e) {
                    log.error("[TransactionScheduler] Error reminding user id={}: {}", acc.getId(), e.getMessage());
                }
            }
        }

        log.info("[TransactionScheduler] Reminded {} users to record. ({} users have recorded today)",
                count, usersWithTx.size());
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 6 — Tổng kết chi tiêu tuần (20:00 Chủ nhật) - GOM TỪ REMINDERSCHEDULER
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 20 * * SUN")
    @Transactional
    public void weeklyDigest() {
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDateTime weekStart = today.minusDays(6).atStartOfDay(); // Bắt đầu tuần (7 ngày trước)
        LocalDateTime weekEnd = today.atTime(23, 59, 59); // Kết thúc ngày hôm nay

        log.info("[TransactionScheduler] Creating weekly digest ({} → {})...", weekStart.toLocalDate(), today);

        List<Account> allActive = accountRepository.findAll();
        int sentCount = 0;

        // [6.1] Vòng lặp qua tất cả account để tổng kết chi tiêu tuần
        for (Account acc : allActive) {
            try {
                // [6.1.1] Tính tổng chi tuần
                BigDecimal totalSpent = transactionRepository
                        .sumExpenseForAccountInPeriod(acc.getId(), weekStart, weekEnd);

                if (totalSpent == null || totalSpent.compareTo(BigDecimal.ZERO) == 0) {
                    continue; // Bỏ qua nếu không chi gì
                }

                // [6.1.2] Lấy top danh mục chi nhiều nhất
                List<Object[]> topCategories = transactionRepository
                        .findTopExpenseCategoriesForAccount(acc.getId(), weekStart, weekEnd);

                if (topCategories.isEmpty()) {
                    continue; // Bỏ qua nếu không có category
                }

                String topName = (String) topCategories.get(0)[0]; // Tên category top 1
                BigDecimal topAmount = (BigDecimal) topCategories.get(0)[1]; // Số tiền top 1

                // [6.1.3] Gửi thông báo tổng kết
                NotificationContent msg = NotificationMessages.weeklyDigest(
                        totalSpent, topName, topAmount);
                notificationService.createNotification(
                        acc,
                        msg.title(),
                        msg.content(),
                        NotificationType.TRANSACTION,
                        null,
                        null
                );
                sentCount++;
            } catch (Exception e) {
                log.error("[TransactionScheduler] Error creating weekly digest for user id={}: {}", acc.getId(), e.getMessage());
            }
        }

        log.info("[TransactionScheduler] Sent weekly digest to {} users.", sentCount);
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 7 — Phát hiện chi tiêu bất thường theo số lượng (>10 giao dịch, 20:00 mỗi tối) - GOM TỪ WALLETSCHEDULER
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 20 * * *")
    @Transactional
    public void checkAbnormalTransactionCount() {
        LocalDateTime since = LocalDateTime.now().minusHours(24); // 24h trước

        log.info("[TransactionScheduler] Checking abnormal spending in last 24h...");

        // [7.1] Lấy danh sách ví bất thường
        List<Object[]> abnormalWallets = transactionRepository
                .findAbnormalExpenseWallets(since, ABNORMAL_TX_THRESHOLD);

        if (abnormalWallets.isEmpty()) {
            log.info("[TransactionScheduler] No abnormal spending detected.");
            return; // Trả về không làm gì
        }

        // [7.2] Lấy danh sách admin
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");

        int count = 0;
        // [7.3] Vòng lặp qua từng ví bất thường
        for (Object[] row : abnormalWallets) {
            try {
                Integer walletId = (Integer) row[0]; // ID ví
                long txCount = (Long) row[1]; // Số giao dịch
                BigDecimal totalAmt = (BigDecimal) row[2]; // Tổng số tiền

                Wallet wallet = walletRepository.findById(walletId).orElse(null);
                if (wallet == null) continue; // Bỏ qua nếu ví không tồn tại

                // [7.3.1] Gửi cảnh báo cho USER
                NotificationContent userMsg = NotificationMessages.abnormalWalletActivity(
                        wallet.getWalletName(), (int) txCount, totalAmt);
                notificationService.createNotification(
                        wallet.getAccount(),
                        userMsg.title(),
                        userMsg.content(),
                        NotificationType.WALLETS,
                        Long.valueOf(walletId),
                        null
                );

                // [7.3.2] Gửi cảnh báo cho ADMIN
                for (Account admin : admins) {
                    NotificationContent adminMsg = NotificationMessages.adminWalletRiskAlert(
                            wallet.getAccount().getAccEmail(),
                            wallet.getWalletName(), (int) txCount, totalAmt);
                    notificationService.createNotification(
                            admin,
                            adminMsg.title(),
                            adminMsg.content(),
                            NotificationType.SYSTEM,
                            Long.valueOf(walletId),
                            null
                    );
                }

                count++;
                log.warn("[TransactionScheduler] Wallet '{}' (id={}) abnormal: {} transactions, total {}",
                        wallet.getWalletName(), walletId, txCount, totalAmt);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Error processing abnormal wallet: {}", e.getMessage());
            }
        }

        log.info("[TransactionScheduler] Warned {} abnormal wallets.", count);
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 8 — Phân tích xu hướng chi tiêu tháng (1:00 AM ngày 1 mỗi tháng)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 1 1 * ?")
    @Transactional
    public void analyzeMonthlyTrend() {
        log.info("[TransactionScheduler] Bắt đầu phân tích xu hướng chi tiêu tháng");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDate thisMonthStart = today.withDayOfMonth(1); // Ngày 1 tháng này
        LocalDate lastMonthStart = thisMonthStart.minusMonths(1); // Ngày 1 tháng trước
        LocalDate lastMonthEnd = thisMonthStart.minusDays(1); // Ngày cuối tháng trước

        // [8.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        // [8.2] Vòng lặp qua tất cả account để phân tích xu hướng
        for (Account account : accounts) {
            try {
                analyzeMonthlyTrendForAccount(account, thisMonthStart, lastMonthStart, lastMonthEnd);
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi phân tích xu hướng tháng cho account id={}: {}", account.getId(), e.getMessage());
            }
        }
    }

    /**
     * [8.1] Phân tích xu hướng tháng cho một account cụ thể.
     * @param account - Account cần phân tích
     * @param thisMonthStart - Bắt đầu tháng này
     * @param lastMonthStart - Bắt đầu tháng trước
     * @param lastMonthEnd - Kết thúc tháng trước
     */
    private void analyzeMonthlyTrendForAccount(Account account, LocalDate thisMonthStart, 
            LocalDate lastMonthStart, LocalDate lastMonthEnd) {
        // [8.1.1] Tính tổng chi tháng này
        LocalDateTime thisMonthStartDt = thisMonthStart.atStartOfDay(); // Bắt đầu tháng này
        LocalDateTime todayEnd = LocalDate.now().atTime(23, 59, 59); // Kết thúc ngày hôm nay
        BigDecimal thisMonthSpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), thisMonthStartDt, todayEnd);

        // [8.1.2] Tính tổng chi tháng trước
        LocalDateTime lastMonthStartDt = lastMonthStart.atStartOfDay(); // Bắt đầu tháng trước
        LocalDateTime lastMonthEndDt = lastMonthEnd.atTime(23, 59, 59); // Kết thúc tháng trước
        BigDecimal lastMonthSpent = transactionRepository.sumExpenseForAccountInPeriod(
                account.getId(), lastMonthStartDt, lastMonthEndDt);

        // [8.1.3] Nếu tháng trước không chi gì → không so sánh
        if (lastMonthSpent.compareTo(BigDecimal.ZERO) == 0) {
            return; // Trả về không làm gì
        }

        // [8.1.4] Tính % tăng
        BigDecimal increaseRate = thisMonthSpent.subtract(lastMonthSpent)
                .divide(lastMonthSpent, 2, RoundingMode.HALF_UP);

        // [8.1.5] Nếu tăng quá ngưỡng → cảnh báo
        if (increaseRate.compareTo(BigDecimal.valueOf(WEEKLY_INCREASE_THRESHOLD)) > 0) {
            NotificationContent msg = NotificationMessages.monthlyTrendAlert(
                    thisMonthSpent, lastMonthSpent, increaseRate);
            notificationService.createNotification(
                    account,
                    msg.title(),
                    msg.content(),
                    NotificationType.TRANSACTION,
                    null,
                    null
            );
            log.info("[TransactionScheduler] Đã gửi cảnh báo xu hướng chi tiêu tháng cho account id={}", account.getId());
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 9 — Tổng kết chi tiêu tháng (1:00 AM ngày 1 mỗi tháng)
    // ══════════════════════════════════════════════════════════════════════
    @Scheduled(cron = "0 0 1 1 * ?")
    @Transactional
    public void monthlyDigest() {
        log.info("[TransactionScheduler] Bắt đầu tổng kết chi tiêu tháng");
        LocalDate today = LocalDate.now(); // Ngày hôm nay
        LocalDate monthStart = today.withDayOfMonth(1); // Ngày 1 tháng này
        LocalDateTime monthStartDt = monthStart.atStartOfDay(); // Bắt đầu tháng này
        LocalDateTime monthEndDt = today.atTime(23, 59, 59); // Kết thúc ngày hôm nay

        // [9.1] Lấy tất cả user active
        List<Account> accounts = accountRepository.findAll();
        int sentCount = 0;

        // [9.2] Vòng lặp qua tất cả account để tổng kết chi tiêu tháng
        for (Account acc : accounts) {
            try {
                // [9.2.1] Tính tổng chi tháng
                BigDecimal thisMonthSpent = transactionRepository
                        .sumExpenseForAccountInPeriod(acc.getId(), monthStartDt, monthEndDt);

                if (thisMonthSpent == null || thisMonthSpent.compareTo(BigDecimal.ZERO) == 0) {
                    continue; // Bỏ qua nếu không chi gì
                }

                // [9.2.2] Lấy top danh mục chi nhiều nhất
                List<Object[]> topCategories = transactionRepository
                        .findTopExpenseCategoriesForAccount(acc.getId(), monthStartDt, monthEndDt);

                if (topCategories.isEmpty()) {
                    continue; // Bỏ qua nếu không có category
                }

                // [9.2.3] Gửi thông báo tổng kết
                NotificationContent msg = NotificationMessages.monthlyDigest(
                        thisMonthSpent, topCategories);
                notificationService.createNotification(
                        acc,
                        msg.title(),
                        msg.content(),
                        NotificationType.TRANSACTION,
                        null,
                        null
                );
                sentCount++;
            } catch (Exception e) {
                log.error("[TransactionScheduler] Lỗi tạo tổng kết tháng cho user id={}: {}", acc.getId(), e.getMessage());
            }
        }

        log.info("[TransactionScheduler] Đã gửi tổng kết tháng cho {} users.", sentCount);
    }
}
