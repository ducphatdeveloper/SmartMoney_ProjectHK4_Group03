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

    // Ngưỡng cảnh báo
    private static final int WARN_THRESHOLD    = 80;
    private static final int EXCEED_THRESHOLD  = 100;

    @Scheduled(cron = "0 0 8 * * *")
    public void checkBudgets() {
        LocalDate today = LocalDate.now();
        List<Budget> activeBudgets = budgetRepository.findActiveBudgets(today);
        log.info("[BudgetScheduler] Kiểm tra {} ngân sách...", activeBudgets.size());

        for (Budget budget : activeBudgets) {
            try {
                self.checkAndNotify(budget);
            } catch (Exception e) {
                log.error("[BudgetScheduler] Lỗi ngân sách id={}: {}", budget.getId(), e.getMessage());
            }
        }
    }

    @Scheduled(cron = "0 0 1 * * *")
    public void renewRecurringBudgets() {
        LocalDate today = LocalDate.now();
        List<Budget> expiredRepeating = budgetRepository.findExpiredRepeatingBudgets(today);
        log.info("[BudgetScheduler] Gia hạn {} ngân sách lặp lại...", expiredRepeating.size());

        for (Budget old : expiredRepeating) {
            try {
                self.renewBudget(old);
            } catch (Exception e) {
                log.error("[BudgetScheduler] Lỗi gia hạn ngân sách id={}: {}", old.getId(), e.getMessage());
            }
        }
    }

    // ── HELPERS ─────────────────────────────────────────────────────────────

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void checkAndNotify(Budget budget) {
        Set<Integer> categoryIds = resolveCategoryIds(budget);
        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        //List<Integer> walletId = Collections.singletonList(budget.getWallet() != null ? budget.getWallet().getId() : null); // Budget trong he thong chi thuoc null hoac 1 vi ko sai dongg nay

        BigDecimal spent = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(),
                budget.getBeginDate().atStartOfDay(),
                budget.getEndDate().atTime(23, 59, 59),
                walletId,
                budget.getAllCategories(),
                categoryIds
        );
        if (spent == null) spent = BigDecimal.ZERO;

        int percent = spent
                .divide(budget.getAmount(), 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .intValue();

        // Label cho ngân sách (tên category hoặc "Tất cả danh mục")
        String budgetLabel = Boolean.TRUE.equals(budget.getAllCategories())
                ? "Tất cả danh mục"
                : budget.getCategories().stream()
                .map(Category::getCtgName)
                .collect(Collectors.joining(", "));

        NotificationContent msg;
        if (percent >= EXCEED_THRESHOLD) {
            msg = NotificationMessages.budgetExceeded(budgetLabel, percent, spent, budget.getAmount());
        } else if (percent >= WARN_THRESHOLD) {
            msg = NotificationMessages.budgetWarning(budgetLabel, percent, spent, budget.getAmount());
        } else {
            log.info("[BudgetScheduler] Ngân sách id={} ổn định ({}%). Không thông báo.", budget.getId(), percent);
            return;
        }

        notificationService.createNotification(
                budget.getAccount(),
                msg.title(), msg.content(),
                NotificationType.BUDGET,
                Long.valueOf(budget.getId()),
                null
        );
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void renewBudget(Budget old) {
        long duration      = ChronoUnit.DAYS.between(old.getBeginDate(), old.getEndDate());
        LocalDate newStart = old.getEndDate().plusDays(1);
        LocalDate newEnd   = newStart.plusDays(duration);

        Budget newBudget = Budget.builder()
                .account(old.getAccount())
                .wallet(old.getWallet())
                .amount(old.getAmount())
                .beginDate(newStart)
                .endDate(newEnd)
                .allCategories(old.getAllCategories())
                .repeating(true)
                .categories(new HashSet<>(old.getCategories()))
                .build();
        budgetRepository.save(newBudget);

        old.setRepeating(false);
        budgetRepository.save(old);

        log.info("[BudgetScheduler] Gia hạn ngân sách id={} → [{} → {}]", old.getId(), newStart, newEnd);

        NotificationContent msg = NotificationMessages.budgetRenewed(newStart, newEnd);
        notificationService.createNotification(
                old.getAccount(),
                msg.title(), msg.content(),
                NotificationType.BUDGET,
                Long.valueOf(newBudget.getId()),
                null
        );
    }

    private Set<Integer> resolveCategoryIds(Budget budget) {
        if (Boolean.TRUE.equals(budget.getAllCategories())) return Set.of();
        return budget.getCategories().stream()
                .map(Category::getId)
                .collect(Collectors.toSet());
    }
}
