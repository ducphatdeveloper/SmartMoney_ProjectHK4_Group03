package fpt.aptech.server.dto.budget;

import fpt.aptech.server.enums.budget.BudgetType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

@Builder
public record BudgetRequest(

        @NotNull(message = "Amount is required")
        @DecimalMin(value = "0.0", inclusive = false, message = "Amount must be greater than 0")
        BigDecimal amount,

        @NotNull(message = "Start date is required")
        LocalDate beginDate,

        @NotNull(message = "End date is required")
        LocalDate endDate,

        @NotNull(message = "Wallet is required")
        Integer walletId,       // null → áp dụng cho tất cả ví

        @NotNull(message = "allCategories is required")
        Boolean allCategories,  // true → Tất cả danh mục chi | false → theo categoryId

        Integer categoryId,     // null nếu allCategories=true
        // id cha → expand cha + toàn bộ con
        // id con → chỉ con đó

        @NotNull(message = "repeating is required")
        Boolean repeating   ,    // true → tự động tạo ngân sách mới khi hết kỳ

        @NotNull(message = "Budget type is required")
        BudgetType budgetType

) {}