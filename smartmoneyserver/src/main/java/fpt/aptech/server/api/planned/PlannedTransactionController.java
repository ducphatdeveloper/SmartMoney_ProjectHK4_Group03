package fpt.aptech.server.api.planned;

import fpt.aptech.server.dto.planned.PlannedTransactionRequest;
import fpt.aptech.server.dto.planned.PlannedTransactionResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.view.BillTransactionListResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.scheduler.planned.PlannedTransactionScheduler;
import fpt.aptech.server.service.planned.PlannedTransactionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
public class PlannedTransactionController {

    private final PlannedTransactionService plannedService;
    private final PlannedTransactionScheduler scheduler; // Inject Scheduler

    // ════════════════════════════════════════════════════════════════════
    // RECURRING — Giao dịch định kỳ (tự động)
    // ════════════════════════════════════════════════════════════════════

    @GetMapping("/api/recurring")
    public ResponseEntity<ApiResponse<List<PlannedTransactionResponse>>> getRecurring(
            @RequestParam(defaultValue = "true") Boolean active,
            @AuthenticationPrincipal Account currentUser) {
        List<PlannedTransactionResponse> data = plannedService.getRecurring(currentUser.getId(), active);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/api/recurring/{id}")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> getRecurringById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.getRecurringById(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @PostMapping("/api/recurring")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> createRecurring(
            @Valid @RequestBody PlannedTransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.createRecurring(request, currentUser.getId());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(data, "Tạo giao dịch định kỳ thành công."));
    }

    @PutMapping("/api/recurring/{id}")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> updateRecurring(
            @PathVariable Integer id,
            @Valid @RequestBody PlannedTransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.updateRecurring(id, request, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data, "Cập nhật giao dịch định kỳ thành công."));
    }

    @DeleteMapping("/api/recurring/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteRecurring(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        plannedService.deleteRecurring(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Xóa giao dịch định kỳ thành công."));
    }

    @PatchMapping("/api/recurring/{id}/toggle")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> toggleRecurring(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.toggleRecurring(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data, "Cập nhật trạng thái giao dịch định kỳ thành công."));
    }

    // ════════════════════════════════════════════════════════════════════
    // BILLS — Hóa đơn (duyệt tay)
    // ════════════════════════════════════════════════════════════════════

    @GetMapping("/api/bills")
    public ResponseEntity<ApiResponse<List<PlannedTransactionResponse>>> getBills(
            @RequestParam(defaultValue = "true") Boolean active,
            @AuthenticationPrincipal Account currentUser) {
        List<PlannedTransactionResponse> data = plannedService.getBills(currentUser.getId(), active);
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @GetMapping("/api/bills/{id}")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> getBillById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.getBillById(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data));
    }

    @PostMapping("/api/bills")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> createBill(
            @Valid @RequestBody PlannedTransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.createBill(request, currentUser.getId());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(data, "Tạo hóa đơn thành công."));
    }

    @PutMapping("/api/bills/{id}")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> updateBill(
            @PathVariable Integer id,
            @Valid @RequestBody PlannedTransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.updateBill(id, request, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data, "Cập nhật hóa đơn thành công."));
    }

    @DeleteMapping("/api/bills/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteBill(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        plannedService.deleteBill(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Xóa hóa đơn thành công."));
    }

    @PostMapping("/api/bills/{id}/pay")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> payBill(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.payBill(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data, "Thanh toán hóa đơn thành công."));
    }

    @PatchMapping("/api/bills/{id}/toggle")
    public ResponseEntity<ApiResponse<PlannedTransactionResponse>> toggleBill(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        PlannedTransactionResponse data = plannedService.toggleBill(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(data, "Cập nhật trạng thái hóa đơn thành công."));
    }

    // ════════════════════════════════════════════════════════════════════
    // XEM GIAO DỊCH LIÊN QUAN
    // ════════════════════════════════════════════════════════════════════

    // [3.1] GET /api/bills/{id}/transactions — Chỉ Bills (plan_type=1)
    // Trả về: totalCount + summary (totalIncome/totalExpense) + groupedTransactions (gom theo ngày)
    @GetMapping("/api/bills/{id}/transactions")
    public ResponseEntity<ApiResponse<BillTransactionListResponse>> getBillTransactions(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        return ResponseEntity.ok(ApiResponse.success(
                plannedService.getBillTransactions(id, currentUser.getId())));
    }

    // ════════════════════════════════════════════════════════════════════
    // SCHEDULER TRIGGER (for testing)
    // ════════════════════════════════════════════════════════════════════

    @PostMapping("/api/planned/check-now")
    public ResponseEntity<ApiResponse<String>> checkNow() {
        scheduler.checkNow();
        return ResponseEntity.ok(ApiResponse.success("Đã kích hoạt scheduler kiểm tra giao dịch định kỳ và hóa đơn."));
    }
}
