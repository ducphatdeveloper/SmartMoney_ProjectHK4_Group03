package fpt.aptech.server.dto.budget;

import fpt.aptech.server.dto.category.CategoryResponse;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter
@Builder
public class BudgetResponse {
    private Integer id;
    private BigDecimal amount;
    private LocalDate beginDate;
    private LocalDate endDate;
    private Integer walletId;
    private String walletName;
    private Boolean allCategories;
    private Boolean repeating;
    private List<CategoryResponse> categories;
}