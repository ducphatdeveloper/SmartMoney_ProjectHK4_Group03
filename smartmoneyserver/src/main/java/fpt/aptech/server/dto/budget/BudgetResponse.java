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
    private BigDecimal dailyShouldSpend;  // Nên chi hàng ngày = remainingAmount / daysLeft
    private BigDecimal dailyActualSpend;  // Thực tế chi hàng ngày = spentAmount / daysElapsed
    private BigDecimal projectedSpend;    // Dự kiến chi tiêu = dailyActual * totalDays

    private BudgetType budgetType;
}