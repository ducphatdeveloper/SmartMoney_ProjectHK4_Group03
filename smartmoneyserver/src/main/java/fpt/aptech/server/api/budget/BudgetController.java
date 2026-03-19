package fpt.aptech.server.api.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.scheduler.budget.BudgetScheduler;
import fpt.aptech.server.service.budget.BudgetService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/budgets")
@RequiredArgsConstructor
public class BudgetController {

    private final BudgetService budgetService;
    private final BudgetScheduler budgetScheduler;

    /// Ngân sách đang hoạt động (endDate >= today)
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<BudgetResponse>>> getBudgets(
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                budgetService.getBudgets(currentUser.getId())));
    }

    /// Ngân sách đã kết thúc (endDate < today)
    @GetMapping("/expired")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<BudgetResponse>>> getExpiredBudgets(
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                budgetService.getExpiredBudgets(currentUser.getId())));
    }

    /// Chi tiết ngân sách
    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> getBudgetById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                budgetService.getBudgetById(id, currentUser.getId())));
    }

    /// Danh sách giao dịch thuộc ngân sách
    @GetMapping("/{id}/transactions")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<TransactionResponse>>> getBudgetTransactions(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                budgetService.getBudgetTransactions(id, currentUser.getId())));
    }

    /// Tạo ngân sách mới
    @PostMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> createBudget(
            @Valid @RequestBody BudgetRequest request,
            @AuthenticationPrincipal Account currentUser) {
        BudgetResponse newBudget = budgetService.createBudget(request, currentUser.getId());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(newBudget, "Tạo ngân sách thành công"));
    }

    /// Cập nhật ngân sách
    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> updateBudget(
            @PathVariable Integer id,
            @Valid @RequestBody BudgetRequest request,
            @AuthenticationPrincipal Account currentUser) {
        BudgetResponse updated = budgetService.updateBudget(id, request, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(updated, "Cập nhật ngân sách thành công"));
    }

    /// Xóa ngân sách (không xóa giao dịch)
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteBudget(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        budgetService.deleteBudget(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Xóa ngân sách thành công"));
    }

    /// Trigger kiểm tra ngân sách thủ công (test only)
    @PostMapping("/check-now")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<String>> triggerBudgetCheck() {
        budgetScheduler.checkBudgets();
        return ResponseEntity.ok(ApiResponse.success("Đã kích hoạt kiểm tra ngân sách."));
    }
}