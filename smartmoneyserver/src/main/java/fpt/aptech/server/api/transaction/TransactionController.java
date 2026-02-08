package fpt.aptech.server.api.transaction;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.TransactionRequest;
import fpt.aptech.server.dto.transaction.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.transaction.TransactionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;

    /**
     * API để tạo một giao dịch mới.
     */
    @PostMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionResponse>> createTransaction(
            @Valid @RequestBody TransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        TransactionResponse newTransaction = transactionService.createTransaction(request, userId);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success(newTransaction, "Tạo giao dịch thành công."));
    }

    /**
     * API để lấy danh sách tất cả giao dịch của người dùng hiện tại.
     */
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<TransactionResponse>>> getTransactions(
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        List<TransactionResponse> transactions = transactionService.getTransactionsByCurrentUser(userId);
        
        return ResponseEntity.ok(ApiResponse.success(transactions));
    }

    /**
     * API để lấy thông tin chi tiết của một giao dịch.
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionResponse>> getTransactionById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        TransactionResponse transaction = transactionService.getTransactionById(id, userId);
        
        return ResponseEntity.ok(ApiResponse.success(transaction));
    }

    /**
     * API để cập nhật một giao dịch.
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionResponse>> updateTransaction(
            @PathVariable Integer id,
            @Valid @RequestBody TransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        TransactionResponse updatedTransaction = transactionService.updateTransaction(id, request, userId);
        
        return ResponseEntity.ok(ApiResponse.success(updatedTransaction, "Cập nhật giao dịch thành công."));
    }

    /**
     * API để xóa (mềm) một giao dịch.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteTransaction(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        transactionService.deleteTransaction(id, userId);
        
        return ResponseEntity.ok(ApiResponse.success("Xóa giao dịch thành công."));
    }
}
