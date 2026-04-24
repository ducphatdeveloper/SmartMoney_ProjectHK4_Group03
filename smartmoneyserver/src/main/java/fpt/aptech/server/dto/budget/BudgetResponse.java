package fpt.aptech.server.dto.budget;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.enums.budget.BudgetType;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter
@Builder
public class BudgetResponse {

    // ── Thông tin cơ bản ──────────────────────────────────────────────────────
    private Integer id;
    private BigDecimal amount;          // Hạn mức ngân sách
    private LocalDate beginDate;
    private LocalDate endDate;
    private Integer walletId;           // null = tất cả ví
    private String walletName;          // null = "Tổng cộng"
    private Boolean allCategories;
    private Boolean repeating;

    private    Boolean exceeded;// đã vượt
    private    Boolean warning; // sắp vượt
    private    BigDecimal progress; // % tiến độ (0 → 1)

    private List<CategoryResponse> categories; // rỗng nếu allCategories=true

    // ── Icon danh mục chính (Flutter hiển thị) ────────────────────────────────
    private Integer primaryCategoryId;          // 1. ID danh mục chính (null nếu allCategories=true)
    private String primaryCategoryIconUrl;      // 2. Icon URL danh mục chính (null nếu allCategories=true)

    // ── Trạng thái ───────────────────────────────────────────────────────────
    private boolean expired;            // endDate < today

    // ── Thực chi ─────────────────────────────────────────────────────────────
    private BigDecimal spentAmount;     // Đã chi
    private BigDecimal remainingAmount; // Còn lại (amount - spentAmount)

    // ── Chỉ số dự đoán ───────────────────────────────────────────────────────
    private BigDecimal dailyShouldSpend;  // Số tiền nên chi mỗi ngày để không vượt ngân sách = remainingAmount / daysLeft
    private BigDecimal dailyActualSpend;  // Trung bình chi mỗi ngày thực tế = spentAmount / daysElapsed (từ ngày bắt đầu đến hôm nay)
    private BigDecimal projectedSpend;    // Dự kiến tổng chi nếu tiếp tục mức chi hiện tại = dailyActual * totalDays

    // ── Đề xuất dựa trên lịch sử 3 tháng ───────────────────────────────────────
    private BigDecimal suggestedAmount;       // Ngân sách đề xuất dựa trên lịch sử chi tiêu 3 tháng gần nhất
    private BigDecimal suggestedDailySpend;   // Trung bình chi mỗi ngày từ lịch sử 3 tháng
    private BigDecimal suggestedWeeklySpend;  // Ngân sách đề xuất hàng tuần (dailyAverage * 7)
    private BigDecimal suggestedMonthlySpend; // Ngân sách đề xuất hàng tháng (dailyAverage * số ngày thực tế của tháng)
    private BigDecimal suggestedYearlySpend;  // Ngân sách đề xuất hàng năm (dailyAverage * số ngày thực tế của năm)
    private BigDecimal suggestedCustomSpend;  // Ngân sách đề xuất custom period (dailyAverage * số ngày custom)
    private BudgetType budgetType;            // Loại ngân sách (WEEKLY, MONTHLY, YEARLY, CUSTOM)
    private BigDecimal overBudgetAmount;       // Số tiền vượt ngân sách = max(0, spentAmount - amount)
}

