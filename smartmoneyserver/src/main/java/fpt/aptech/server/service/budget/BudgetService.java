package fpt.aptech.server.service.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;

import java.util.List;

public interface BudgetService {

    // ── Danh sách ─────────────────────────────────────────────────────────────
    List<BudgetResponse> getBudgets(Integer userId , Integer walletId);           // active budgets
    List<BudgetResponse> getExpiredBudgets(Integer userId);   // expired budgets

    // ── Chi tiết ──────────────────────────────────────────────────────────────
    BudgetResponse getBudgetById(Integer budgetId, Integer userId);

    // ── Giao dịch thuộc ngân sách ─────────────────────────────────────────────
    List<TransactionResponse> getBudgetTransactions(Integer budgetId, Integer userId);

    // ── CRUD ──────────────────────────────────────────────────────────────────
    BudgetResponse createBudget(BudgetRequest request, Integer userId);
    BudgetResponse updateBudget(Integer budgetId, BudgetRequest request, Integer userId);
    void deleteBudget(Integer budgetId, Integer userId);
}