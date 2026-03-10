package fpt.aptech.server.api.transaction;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.FinancialReportResponse;
import fpt.aptech.server.dto.transaction.report.TransactionReportResponse;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.request.TransactionSearchRequest;
import fpt.aptech.server.dto.transaction.view.CategoryTransactionGroup;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.enums.date.DateRange;
import fpt.aptech.server.service.transaction.TransactionService;
import fpt.aptech.server.utils.date.DateUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;

    // =========================================================================
    // NHÓM API XEM DANH SÁCH & BÁO CÁO (Hỗ trợ `range`)
    // =========================================================================

    /**
     * Lấy danh sách giao dịch cho màn hình Nhật ký, đã gom nhóm theo ngày.
     * <p>
     * <b>Cách dùng:</b><br>
     * 1. Dùng khoảng thời gian tương đối: {@code ?range=THIS_MONTH}<br>
     * 2. Dùng khoảng thời gian tùy chỉnh: {@code ?range=CUSTOM&startDate=...&endDate=...}
     */
    @GetMapping("/journal")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<DailyTransactionGroup>>> getJournalTransactions(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @AuthenticationPrincipal Account currentUser) {

        // "Dịch" range hoặc startDate/endDate thành một khoảng thời gian cụ thể
        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        List<DailyTransactionGroup> transactions = transactionService.getJournalTransactions(userId, dates[0], dates[1], walletId, savingGoalId);
        return ResponseEntity.ok(ApiResponse.success(transactions));
    }

    /**
     * Lấy danh sách giao dịch đã gom nhóm theo Danh mục.
     */
    @GetMapping("/grouped")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<CategoryTransactionGroup>>> getGroupedTransactions(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @AuthenticationPrincipal Account currentUser) {

        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        List<CategoryTransactionGroup> transactions = transactionService.getGroupedTransactions(userId, dates[0], dates[1], walletId, savingGoalId);
        return ResponseEntity.ok(ApiResponse.success(transactions));
    }

    /**
     * Lấy báo cáo tài chính tổng quan (Số dư, Tổng thu/chi).
     */
    @GetMapping("/report/summary")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionReportResponse>> getTransactionReport(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @AuthenticationPrincipal Account currentUser) {

        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        TransactionReportResponse report = transactionService.getTransactionReport(userId, dates[0], dates[1], walletId, savingGoalId);
        return ResponseEntity.ok(ApiResponse.success(report));
    }

    /**
     * Lấy báo cáo chi tiết theo từng danh mục (dùng cho biểu đồ tròn).
     */
    @GetMapping("/report/category")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<CategoryReportDTO>>> getCategoryReport(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @AuthenticationPrincipal Account currentUser) {

        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        List<CategoryReportDTO> report = transactionService.getCategoryReport(userId, dates[0], dates[1], walletId, savingGoalId);
        return ResponseEntity.ok(ApiResponse.success(report));
    }

    /**
     * Lấy báo cáo tài chính toàn diện (All-in-One Dashboard).
     */
    @GetMapping("/report/financial")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<FinancialReportResponse>> getFinancialReport(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @AuthenticationPrincipal Account currentUser) {

        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        FinancialReportResponse report = transactionService.getFinancialReport(userId, dates[0], dates[1], walletId, savingGoalId);
        return ResponseEntity.ok(ApiResponse.success(report));
    }

    /**
     * Lấy dữ liệu xu hướng thu/chi theo từng ngày (dùng cho biểu đồ cột/đường).
     */
    @GetMapping("/report/trend")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<DailyTrendDTO>>> getDailyTrend(
            @RequestParam(value = "startDate", required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate", required = false) LocalDateTime endDate,
            @RequestParam(value = "range", required = false) DateRange range,
            @RequestParam(value = "walletId", required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @RequestParam(value = "categoryId", required = false) Integer categoryId,
            @AuthenticationPrincipal Account currentUser) {

        LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
        Integer userId = currentUser.getId();

        List<DailyTrendDTO> trend = transactionService.getDailyTrend(userId, dates[0], dates[1], walletId, savingGoalId, categoryId);
        return ResponseEntity.ok(ApiResponse.success(trend));
    }

    // =========================================================================
    // NHÓM API HÀNH ĐỘNG (Không dùng `range`)
    // =========================================================================

    /**
     * Tạo một giao dịch mới.
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
     * Tìm kiếm giao dịch nâng cao theo nhiều tiêu chí phức tạp.
     * <p>
     * <b>Lưu ý:</b> Khoảng thời gian được truyền trong body của {@code TransactionSearchRequest},
     * không dùng {@code range} trên URL.
     */
    @PostMapping("/search")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<TransactionResponse>>> searchTransactions(
            @RequestBody TransactionSearchRequest request,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        List<TransactionResponse> results = transactionService.searchTransactions(userId, request);

        return ResponseEntity.ok(ApiResponse.success(results));
    }

    /**
     * Lấy thông tin chi tiết của một giao dịch theo ID.
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionResponse>> getTransactionById(
            @PathVariable Long id,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        TransactionResponse transaction = transactionService.getTransactionById(id, userId);

        return ResponseEntity.ok(ApiResponse.success(transaction));
    }

    /**
     * Cập nhật một giao dịch đã có.
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionResponse>> updateTransaction(
            @PathVariable Long id,
            @Valid @RequestBody TransactionRequest request,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        TransactionResponse updatedTransaction = transactionService.updateTransaction(id, request, userId);

        return ResponseEntity.ok(ApiResponse.success(updatedTransaction, "Cập nhật giao dịch thành công."));
    }

    /**
     * Xóa (mềm) một giao dịch.
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteTransaction(
            @PathVariable Long id,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        transactionService.deleteTransaction(id, userId);

        return ResponseEntity.ok(ApiResponse.success("Xóa giao dịch thành công."));
    }
}