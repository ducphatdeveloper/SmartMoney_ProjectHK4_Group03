package fpt.aptech.server.dto.budget;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Set;

@Builder
public record BudgetRequest(
    @NotNull(message = "Số tiền không được để trống")
    @DecimalMin(value = "0.0", inclusive = false, message = "Số tiền phải lớn hơn 0")
    BigDecimal amount,

    @NotNull(message = "Ngày bắt đầu không được để trống")
    LocalDate beginDate,

    @NotNull(message = "Ngày kết thúc không được để trống")
    LocalDate endDate,

    Integer walletId, // Null nếu áp dụng cho tất cả ví

    @NotNull
    Boolean allCategories, // True: Tất cả danh mục, False: Theo danh sách categories

    @NotNull
    Boolean repeating, // True: Tự động lặp lại

    Set<Integer> categoryIds // Danh sách ID danh mục (nếu allCategories = false)
) {}