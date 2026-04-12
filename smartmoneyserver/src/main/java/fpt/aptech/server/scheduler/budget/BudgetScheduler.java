package fpt.aptech.server.scheduler.budget;

import fpt.aptech.server.entity.Budget;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.BudgetRepository;
import fpt.aptech.server.repos.TransactionRepository;
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

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
//import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Scheduler quản lý thông báo ngân sách.
 *
 * ─── LỊCH CHẠY (CRON) ──────────────────────────────────────────────────
 *   JOB 1 — checkBudgets():           8:00 AM mỗi ngày  → Cảnh báo ngân sách cho user
 *   JOB 2 — renewRecurringBudgets():  1:00 AM mỗi ngày  → Gia hạn ngân sách lặp lại (xử lý nền)
 * ────────────────────────────────────────────────────────────────────────
 *
 * Thông báo được tạo ra (tất cả gọi từ NotificationMessages):
 *   1. budgetWarning()          → "Cảnh báo ngân sách 🔔" — chi >= 80% ngân sách
 *   2. budgetExceeded()         → "Vượt ngân sách! 🚨" — chi >= 100% ngân sách
 *   3. budgetDailyAllowance()   → "💡 Gợi ý chi tiêu hôm nay" — gợi ý mức chi/ngày (tính toán Java thuần)
 *   4. budgetOverrunForecast()  → "🔮 Dự báo vượt ngân sách" — dự báo ngày cạn ngân sách (tính toán Java thuần)
 *   5. budgetComparedToLastMonth() → "📈 Chi tiêu tăng so với tháng trước" — so sánh cùng kỳ (tính toán Java thuần)
 *   6. budgetRenewed()          → "Ngân sách đã được gia hạn 🔄" — gia hạn kỳ mới
 *
 * Bảo mật: Mỗi thông báo gắn budget.getAccount() → chỉ chủ sở hữu ngân sách nhận được.
 * NotificationType: BUDGET (3), related_id = budget.id
 *
 * ⚠️ LƯU Ý: Các bước 5, 6, 7 trong checkAndNotify() là tính toán Java thuần (phép chia, phép trừ)
 *    — KHÔNG liên quan đến AI/ML/LLM — chỉ là logic phân tích đơn giản bằng phép toán BigDecimal.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BudgetScheduler {

    // FIX: Dùng Field Injection để tránh Circular Dependency trong Constructor
    @Autowired
    @Lazy
    private BudgetScheduler self;

    private final BudgetRepository budgetRepository;
    private final TransactionRepository transactionRepository;
    private final NotificationService notificationService;

    // Ngưỡng cảnh báo chính
    private static final int WARN_THRESHOLD    = 80;   // >= 80% → cảnh báo vàng
    private static final int EXCEED_THRESHOLD  = 100;  // >= 100% → cảnh báo đỏ (vượt ngân sách)

    // Ngưỡng phân tích thông minh (tính toán Java thuần — KHÔNG phải AI)
    private static final int DAILY_ALLOWANCE_THRESHOLD = 60;  // >= 60% → gợi ý mức chi/ngày
    private static final int FORECAST_THRESHOLD        = 50;  // >= 50% → dự báo ngày cạn ngân sách
    private static final int COMPARE_INCREASE_THRESHOLD = 30; // tăng >= 30% → cảnh báo so sánh tháng trước
    private static final long MIN_DAYS_FOR_ALLOWANCE   = 5;   // còn > 5 ngày mới tính gợi ý chi/ngày

    // ══════════════════════════════════════════════════════════════════════
    // JOB 1 — Kiểm tra ngân sách (8:00 AM mỗi ngày)
    // Lý do 8h sáng: User vừa thức dậy, nhận cảnh báo ngân sách đầu ngày để điều chỉnh chi tiêu.
    // ══════════════════════════════════════════════════════════════════════

    @Scheduled(cron = "0 0 8 * * *") // 8:00 AM mỗi ngày
    public void checkBudgets() {
        // Bước 1: Lấy ngày hiện tại và tìm tất cả ngân sách đang hoạt động (beginDate <= today <= endDate)
        LocalDate today = LocalDate.now();
        List<Budget> activeBudgets = budgetRepository.findActiveBudgets(today);
        log.info("[BudgetScheduler] Kiểm tra {} ngân sách...", activeBudgets.size());

        // Bước 2: Duyệt từng ngân sách, gọi checkAndNotify() trong transaction riêng biệt
        for (Budget budget : activeBudgets) {
            try {
                self.checkAndNotify(budget); // self-injection để @Transactional(REQUIRES_NEW) hoạt động
            } catch (Exception e) {
                log.error("[BudgetScheduler] Lỗi ngân sách id={}: {}", budget.getId(), e.getMessage());
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // JOB 2 — Gia hạn ngân sách lặp lại (1:00 AM mỗi ngày)
    // Lý do 1h sáng: Xử lý nền khi hệ thống ít tải, gia hạn trước khi user thức dậy.
    // ══════════════════════════════════════════════════════════════════════

    @Scheduled(cron = "0 0 1 * * *") // 1:00 AM mỗi ngày
    public void renewRecurringBudgets() {
        // Bước 1: Tìm ngân sách lặp lại đã hết hạn (endDate < today AND repeating = true)
        LocalDate today = LocalDate.now();
        List<Budget> expiredRepeating = budgetRepository.findExpiredRepeatingBudgets(today);
        log.info("[BudgetScheduler] Gia hạn {} ngân sách lặp lại...", expiredRepeating.size());

        // Bước 2: Gia hạn từng ngân sách trong transaction riêng biệt
        for (Budget old : expiredRepeating) {
            try {
                self.renewBudget(old); // self-injection để @Transactional(REQUIRES_NEW) hoạt động
            } catch (Exception e) {
                log.error("[BudgetScheduler] Lỗi gia hạn ngân sách id={}: {}", old.getId(), e.getMessage());
            }
        }
    }

    // ── HELPERS ─────────────────────────────────────────────────────────────

    /**
     * Kiểm tra 1 ngân sách và gửi các thông báo phù hợp.
     * Mỗi ngân sách có thể tạo TỐI ĐA 4 thông báo (nếu thỏa tất cả điều kiện):
     *   1. Cảnh báo chính (80% hoặc 100%)
     *   2. Gợi ý chi tiêu/ngày
     *   3. Dự báo ngày cạn ngân sách
     *   4. So sánh với tháng trước
     *
     * Bảo mật: Dùng budget.getAccount() → chỉ chủ sở hữu ngân sách nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void checkAndNotify(Budget budget) {
        // ── Bước 1: Tính tổng chi tiêu thực tế cho ngân sách ──
        Set<Integer> categoryIds = resolveCategoryIds(budget); // Lấy danh sách categoryId của ngân sách
        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null; // Ví liên kết (nullable)

        // Query tổng chi tiêu trong khoảng thời gian ngân sách, lọc theo wallet + categories
        BigDecimal spent = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(),
                budget.getBeginDate().atStartOfDay(),
                budget.getEndDate().atTime(23, 59, 59),
                walletId,
                budget.getAllCategories(),         // true = tất cả danh mục, false = chỉ categories đã chọn
                categoryIds
        );
        if (spent == null) spent = BigDecimal.ZERO; // Nếu chưa có giao dịch nào → 0đ

        // ── Bước 2: Tính phần trăm đã chi (spent / amount * 100) ──
        int percent = spent
                .divide(budget.getAmount(), 4, RoundingMode.HALF_UP) // Chia lấy 4 chữ số thập phân
                .multiply(BigDecimal.valueOf(100))                    // Nhân 100 để ra phần trăm
                .intValue();                                          // Ép về int (VD: 85)

        // ── Bước 3: Xác định nhãn ngân sách (tên category hoặc "Tất cả danh mục") ──
        String budgetLabel = Boolean.TRUE.equals(budget.getAllCategories())
                ? "Tất cả danh mục"
                : budget.getCategories().stream()
                .map(Category::getCtgName)      // Lấy tên từng category
                .collect(Collectors.joining(", ")); // Nối bằng dấu phẩy: "Ăn uống, Giải trí"

        // ── Bước 4: Gửi cảnh báo chính (vượt ngưỡng 80% hoặc 100%) ──
        // → Nếu >= 100%: NotificationMessages.budgetExceeded()
        //   Thông báo tạo ra: Title="Vượt ngân sách! 🚨"
        //   Content="Bạn đã vượt 120% ngân sách Ăn uống. Tổng chi: 2.400.000 ₫ / hạn mức 2.000.000 ₫."
        //
        // → Nếu >= 80%: NotificationMessages.budgetWarning()
        //   Thông báo tạo ra: Title="Cảnh báo ngân sách 🔔"
        //   Content="Bạn đã chi 85% ngân sách Ăn uống (1.700.000 ₫/2.000.000 ₫). Hãy cân nhắc chi tiêu!"
        NotificationContent msg = null;
        if (percent >= EXCEED_THRESHOLD) {
            msg = NotificationMessages.budgetExceeded(budgetLabel, percent, spent, budget.getAmount());
        } else if (percent >= WARN_THRESHOLD) {
            msg = NotificationMessages.budgetWarning(budgetLabel, percent, spent, budget.getAmount());
        }

        if (msg != null) {
            notificationService.createNotification(
                    budget.getAccount(),                  // Bảo mật: chỉ chủ ngân sách nhận
                    msg.title(), msg.content(),
                    NotificationType.BUDGET,              // type = 3 (BUDGET)
                    Long.valueOf(budget.getId()),          // related_id = budget.id (để Flutter navigate)
                    null                                   // scheduledTime = null → gửi ngay
            );
        }

        // ── Bước 5: Gợi ý mức chi tiêu theo ngày (tính toán Java thuần — KHÔNG phải AI) ──
        // Công thức: dailyAllowance = (amount - spent) / daysLeft
        // Điều kiện: đã chi >= 60% VÀ còn > 5 ngày VÀ remaining > 0
        // → NotificationMessages.budgetDailyAllowance()
        //   Thông báo tạo ra: Title="💡 Gợi ý chi tiêu hôm nay"
        //   Content="Ngân sách Ăn uống còn 300.000 ₫ cho 10 ngày tới. Mỗi ngày bạn chỉ nên chi tối đa 30.000 ₫ để đảm bảo đủ tháng."
        LocalDate today = LocalDate.now();
        long daysLeft = ChronoUnit.DAYS.between(today, budget.getEndDate()); // Số ngày còn lại

        if (percent >= DAILY_ALLOWANCE_THRESHOLD && daysLeft > MIN_DAYS_FOR_ALLOWANCE) {
            BigDecimal remaining = budget.getAmount().subtract(spent); // Số tiền còn lại = hạn mức - đã chi
            if (remaining.compareTo(BigDecimal.ZERO) > 0) {           // Chỉ gợi ý nếu còn tiền
                BigDecimal dailyAllowance = remaining.divide(          // Chia đều cho số ngày còn lại
                        BigDecimal.valueOf(daysLeft), 0, RoundingMode.HALF_UP);
                NotificationContent dailyMsg = NotificationMessages.budgetDailyAllowance(
                        budgetLabel, remaining, daysLeft, dailyAllowance);
                notificationService.createNotification(
                        budget.getAccount(),               // Bảo mật: chỉ chủ ngân sách nhận
                        dailyMsg.title(), dailyMsg.content(),
                        NotificationType.BUDGET,
                        Long.valueOf(budget.getId()),
                        null
                );
            }
        }

        // ── Bước 6: Dự báo ngày cạn ngân sách (tính toán Java thuần — KHÔNG phải AI) ──
        // Công thức: daysUntilOverrun = (amount - spent) / (spent / daysPassed)
        // Điều kiện: đã chi >= 50% VÀ đã qua > 0 ngày VÀ còn > 0 ngày VÀ forecastDate < endDate
        // → NotificationMessages.budgetOverrunForecast()
        //   Thông báo tạo ra: Title="🔮 Dự báo vượt ngân sách"
        //   Content="Với tốc độ chi tiêu hiện tại, ngân sách Ăn uống của bạn sẽ cạn vào khoảng 25/04/2026 (còn 5 ngày). Hãy điều chỉnh chi tiêu ngay hôm nay!"
        long daysPassed = ChronoUnit.DAYS.between(budget.getBeginDate(), today); // Số ngày đã qua
        if (percent >= FORECAST_THRESHOLD && daysPassed > 0 && daysLeft > 0) {
            // Tính tốc độ chi trung bình/ngày = spent / daysPassed
            BigDecimal dailyBurnRate = spent.divide(BigDecimal.valueOf(daysPassed), 4, RoundingMode.HALF_UP);
            if (dailyBurnRate.compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal remainingBudget = budget.getAmount().subtract(spent); // Ngân sách còn lại
                // Dự báo số ngày nữa sẽ cạn = remainingBudget / dailyBurnRate
                long daysUntilOverrun = remainingBudget
                        .divide(dailyBurnRate, 0, RoundingMode.HALF_UP).longValue();
                LocalDate forecastDate = today.plusDays(daysUntilOverrun); // Ngày dự báo cạn

                // Chỉ gửi nếu dự báo vượt TRƯỚC endDate (nếu sau endDate thì không cần cảnh báo)
                if (forecastDate.isBefore(budget.getEndDate())) {
                    NotificationContent forecastMsg = NotificationMessages.budgetOverrunForecast(
                            budgetLabel, forecastDate, daysUntilOverrun);
                    notificationService.createNotification(
                            budget.getAccount(),            // Bảo mật: chỉ chủ ngân sách nhận
                            forecastMsg.title(), forecastMsg.content(),
                            NotificationType.BUDGET,
                            Long.valueOf(budget.getId()),
                            null
                    );
                }
            }
        }

        // ── Bước 7: So sánh chi tiêu với cùng kỳ tháng trước (tính toán Java thuần — KHÔNG phải AI) ──
        // Công thức: increasePercent = (spent - lastMonthSpent) / lastMonthSpent * 100
        // Điều kiện: đã qua > 0 ngày VÀ tháng trước có chi tiêu VÀ tăng >= 30%
        // → NotificationMessages.budgetComparedToLastMonth()
        //   Thông báo tạo ra: Title="📈 Chi tiêu tăng so với tháng trước"
        //   Content="Bạn đang chi Ăn uống nhiều hơn 45% so với cùng kỳ tháng trước (1.200.000 ₫). Hãy kiểm tra lại thói quen chi tiêu!"
        if (daysPassed > 0) {
            // Tính khoảng cùng kỳ tháng trước (cùng số ngày)
            LocalDate lastMonthStart = budget.getBeginDate().minusMonths(1);
            LocalDate lastMonthEnd = lastMonthStart.plusDays(daysPassed - 1);

            // Query tổng chi tiêu cùng kỳ tháng trước (cùng wallet + categories)
            BigDecimal lastMonthSpent = transactionRepository.sumExpenseForBudget(
                    budget.getAccount().getId(),
                    lastMonthStart.atStartOfDay(),
                    lastMonthEnd.atTime(23, 59, 59),
                    walletId,
                    budget.getAllCategories(),
                    categoryIds
            );
            if (lastMonthSpent == null) lastMonthSpent = BigDecimal.ZERO;

            // Chỉ so sánh nếu tháng trước có chi tiêu (tránh chia cho 0)
            if (lastMonthSpent.compareTo(BigDecimal.ZERO) > 0) {
                // Tính phần trăm tăng = (spent - lastMonthSpent) / lastMonthSpent * 100
                int increasePercent = spent.subtract(lastMonthSpent)
                        .multiply(BigDecimal.valueOf(100))
                        .divide(lastMonthSpent, 0, RoundingMode.HALF_UP)
                        .intValue();

                // Chỉ cảnh báo nếu tăng >= 30% (tránh spam khi chênh lệch nhỏ)
                if (increasePercent >= COMPARE_INCREASE_THRESHOLD) {
                    NotificationContent compareMsg = NotificationMessages.budgetComparedToLastMonth(
                            budgetLabel, increasePercent, lastMonthSpent);
                    notificationService.createNotification(
                            budget.getAccount(),           // Bảo mật: chỉ chủ ngân sách nhận
                            compareMsg.title(), compareMsg.content(),
                            NotificationType.BUDGET,
                            Long.valueOf(budget.getId()),
                            null
                    );
                }
            }
        }

        // ── Log khi ngân sách ổn định (không cần gửi thông báo) ──
        if (msg == null && percent < DAILY_ALLOWANCE_THRESHOLD) {
            log.info("[BudgetScheduler] Ngân sách id={} ổn định ({}%). Không thông báo.", budget.getId(), percent);
        }
    }

    /**
     * Gia hạn 1 ngân sách lặp lại:
     *   - Tạo ngân sách mới với kỳ tiếp theo (cùng duration, cùng amount, cùng categories).
     *   - Đánh dấu ngân sách cũ repeating=false.
     *   - Gửi thông báo xác nhận gia hạn.
     *
     * → NotificationMessages.budgetRenewed()
     *   Thông báo tạo ra: Title="Ngân sách đã được gia hạn 🔄"
     *   Content="Ngân sách của bạn đã được tự động tạo mới cho kỳ 01/05/2026 đến 31/05/2026."
     *
     * Bảo mật: Dùng old.getAccount() → chỉ chủ sở hữu ngân sách nhận được.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void renewBudget(Budget old) {
        // Bước 1: Tính duration (số ngày giữa beginDate và endDate)
        long duration      = ChronoUnit.DAYS.between(old.getBeginDate(), old.getEndDate());

        // Bước 2: Tính ngày bắt đầu và kết thúc kỳ mới (kỳ mới = endDate cũ + 1 ngày)
        LocalDate newStart = old.getEndDate().plusDays(1);
        LocalDate newEnd   = newStart.plusDays(duration);

        // Bước 3: Tạo ngân sách mới (copy toàn bộ cấu hình từ ngân sách cũ)
        Budget newBudget = Budget.builder()
                .account(old.getAccount())               // Giữ nguyên chủ sở hữu
                .wallet(old.getWallet())                 // Giữ nguyên ví liên kết
                .amount(old.getAmount())                 // Giữ nguyên hạn mức
                .beginDate(newStart)                     // Kỳ mới bắt đầu
                .endDate(newEnd)                         // Kỳ mới kết thúc
                .allCategories(old.getAllCategories())    // Giữ nguyên loại danh mục
                .repeating(true)                         // Ngân sách mới vẫn lặp lại
                .categories(new HashSet<>(old.getCategories())) // Copy danh sách categories
                .build();
        budgetRepository.save(newBudget);

        // Bước 4: Đánh dấu ngân sách cũ không còn lặp lại (đã được thay thế bởi newBudget)
        old.setRepeating(false);
        budgetRepository.save(old);

        log.info("[BudgetScheduler] Gia hạn ngân sách id={} → [{} → {}]", old.getId(), newStart, newEnd);

        // Bước 5: Gửi thông báo xác nhận gia hạn
        NotificationContent msg = NotificationMessages.budgetRenewed(newStart, newEnd);
        notificationService.createNotification(
                old.getAccount(),                        // Bảo mật: chỉ chủ ngân sách nhận
                msg.title(), msg.content(),
                NotificationType.BUDGET,                 // type = 3 (BUDGET)
                Long.valueOf(newBudget.getId()),          // related_id = ngân sách MỚI (để Flutter navigate)
                null                                      // scheduledTime = null → gửi ngay
        );
    }

    /**
     * Helper: Lấy danh sách categoryId từ ngân sách.
     * Nếu allCategories=true → trả về Set rỗng (query sẽ không lọc theo category).
     */
    private Set<Integer> resolveCategoryIds(Budget budget) {
        if (Boolean.TRUE.equals(budget.getAllCategories())) return Set.of();
        return budget.getCategories().stream()
                .map(Category::getId)
                .collect(Collectors.toSet());
    }
}
