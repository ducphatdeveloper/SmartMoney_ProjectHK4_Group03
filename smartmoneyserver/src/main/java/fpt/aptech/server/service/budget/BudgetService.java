package fpt.aptech.server.service.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;

import java.util.List;

public interface BudgetService {
    List<BudgetResponse> getBudgets(Integer userId);
    BudgetResponse getBudgetById(Integer budgetId, Integer userId);
    BudgetResponse createBudget(BudgetRequest request, Integer userId);
    BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId);
    void deleteBudget(Integer budgetId, Integer userId);
}