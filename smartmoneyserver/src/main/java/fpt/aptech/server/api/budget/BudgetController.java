package fpt.aptech.server.api.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.budget.BudgetScheduler;
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
    private final BudgetScheduler budgetScheduler; // Inject Scheduler

    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<BudgetResponse>>> getBudgets(
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        List<BudgetResponse> budgets = budgetService.getBudgets(userId);
        return ResponseEntity.ok(ApiResponse.success(budgets));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> getBudgetById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        BudgetResponse budget = budgetService.getBudgetById(id, userId);
        return ResponseEntity.ok(ApiResponse.success(budget));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> createBudget(
            @Valid @RequestBody BudgetRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        BudgetResponse newBudget = budgetService.createBudget(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(newBudget, "Tạo ngân sách thành công"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<BudgetResponse>> updateBudget(
            @PathVariable Integer id,
            @Valid @RequestBody BudgetRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        BudgetResponse updatedBudget = budgetService.updateBudget(id, request, userId);
        return ResponseEntity.ok(ApiResponse.success(updatedBudget, "Cập nhật ngân sách thành công"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteBudget(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        budgetService.deleteBudget(id, userId);
        return ResponseEntity.ok(ApiResponse.success("Xóa ngân sách thành công"));
    }

    // API để kích hoạt kiểm tra ngân sách thủ công (cho mục đích test)
    @PostMapping("/check-now")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<String>> triggerBudgetCheck() {
        budgetScheduler.checkBudgets();
        return ResponseEntity.ok(ApiResponse.success("Đã kích hoạt kiểm tra ngân sách."));
    }
}