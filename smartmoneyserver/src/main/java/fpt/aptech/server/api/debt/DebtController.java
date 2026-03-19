package fpt.aptech.server.api.debt;

import fpt.aptech.server.dto.debt.DebtResponse;
import fpt.aptech.server.dto.debt.DebtUpdateRequest;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.debt.DebtService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/debts")
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
public class DebtController {

    private final DebtService debtService;

    // POST /api/debts đã bị xóa.
    // Debt chỉ được tạo khi tạo transaction "Đi vay / Cho vay".

    @GetMapping
    public ResponseEntity<ApiResponse<List<DebtResponse>>> getDebts(
            @RequestParam Boolean debtType,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                debtService.getDebts(currentUser.getId(), debtType)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<DebtResponse>> getDebt(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                debtService.getDebt(id, currentUser.getId())));
    }

    @GetMapping("/{id}/transactions")
    public ResponseEntity<ApiResponse<List<TransactionResponse>>> getDebtTransactions(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                debtService.getDebtTransactions(id, currentUser.getId())));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DebtResponse>> updateDebt(
            @PathVariable Integer id,
            @Valid @RequestBody DebtUpdateRequest request,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                debtService.updateDebt(id, request, currentUser.getId()),
                "Cập nhật khoản nợ thành công."));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<ApiResponse<DebtResponse>> updateDebtStatus(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                debtService.updateDebtStatus(id, currentUser.getId())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteDebt(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        debtService.deleteDebt(id, currentUser.getId());
        return ResponseEntity.noContent().build();
    }
}