package fpt.aptech.server.dto.budget;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

@Builder
public record BudgetRequest(

        @NotNull(message = "Số tiền không được để trống")
        @DecimalMin(value = "0.0", inclusive = false, message = "Số tiền phải lớn hơn 0")
        BigDecimal amount,

        @NotNull(message = "Ngày bắt đầu không được để trống")
        LocalDate beginDate,

        @NotNull(message = "Ngày kết thúc không được để trống")
        LocalDate endDate,

        Integer walletId,       // null → áp dụng cho tất cả ví

        @NotNull(message = "allCategories không được để trống")
        Boolean allCategories,  // true → Tất cả danh mục chi | false → theo categoryId

        Integer categoryId,     // null nếu allCategories=true
        // id cha → expand cha + toàn bộ con
        // id con → chỉ con đó

        @NotNull(message = "repeating không được để trống")
        Boolean repeating       // true → tự động tạo ngân sách mới khi hết kỳ
) {}