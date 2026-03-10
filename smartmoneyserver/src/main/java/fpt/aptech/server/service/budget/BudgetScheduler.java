package fpt.aptech.server.service.budget;

import fpt.aptech.server.entity.Budget;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.repos.BudgetRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class BudgetScheduler {

    private final BudgetRepository budgetRepository;
    private final TransactionRepository transactionRepository;
    private final NotificationService notificationService;

    // Chạy mỗi ngày lúc 8:00 sáng
    @Scheduled(cron = "0 0 8 * * *")
    @Transactional
    public void checkBudgets() {
        LocalDate today = LocalDate.now();
        List<Budget> activeBudgets = budgetRepository.findActiveBudgets(today);

        for (Budget budget : activeBudgets) {
            checkAndNotify(budget);
        }
    }

    private void checkAndNotify(Budget budget) {
        // 1. Lấy danh sách ID danh mục (nếu không phải allCategories)
        Set<Integer> categoryIds = null;
        if (Boolean.FALSE.equals(budget.getAllCategories())) {
            categoryIds = budget.getCategories().stream()
                    .map(Category::getId)
                    .collect(Collectors.toSet());
        }

        // 2. Tính tổng chi tiêu thực tế
        Integer walletId = budget.getWallet() != null ? budget.getWallet().getId() : null;
        
        BigDecimal totalExpense = transactionRepository.sumExpenseForBudget(
                budget.getAccount().getId(),
                budget.getBeginDate().atStartOfDay(),
                budget.getEndDate().atTime(23, 59, 59),
                walletId,
                budget.getAllCategories(),
                categoryIds
        );

        if (totalExpense == null) {
            totalExpense = BigDecimal.ZERO;
        }

        // 3. Tính phần trăm
        BigDecimal percentage = totalExpense.divide(budget.getAmount(), 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100));

        // 4. Kiểm tra ngưỡng cảnh báo (Ví dụ: 80% và 100%)
        if (percentage.compareTo(BigDecimal.valueOf(100)) >= 0) {
            sendNotification(budget, "Vượt quá ngân sách!", 
                    "Bạn đã chi tiêu vượt quá 100% ngân sách. Tổng chi: " + totalExpense + " / " + budget.getAmount());
        } else if (percentage.compareTo(BigDecimal.valueOf(80)) >= 0) {
            sendNotification(budget, "Cảnh báo ngân sách", 
                    "Bạn đã chi tiêu " + percentage.intValue() + "% ngân sách. Hãy chú ý chi tiêu!");
        }
    }

    private void sendNotification(Budget budget, String title, String content) {
        // TODO: Cần thêm logic kiểm tra xem đã gửi thông báo hôm nay chưa để tránh spam
        // Hiện tại cứ gửi để test
        notificationService.createNotification(
                budget.getAccount(),
                title,
                content,
                NotificationType.BUDGET,
                Long.valueOf(budget.getId()),
                LocalDateTime.now()
        );
    }
}
