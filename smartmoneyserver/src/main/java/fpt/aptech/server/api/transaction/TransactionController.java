package fpt.aptech.server.api.transaction;

import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.merge.TransactionListResponse;
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

    /**
     * Lấy danh sách giao dịch dùng chung với bộ filter động.
     * <p>
     * <b>Khoảng thời gian (tùy chọn):</b><br>
     * - Dùng {@code ?range=THIS_MONTH} hoặc {@code ?range=CUSTOM&startDate=...&endDate=...}<br>
     * - Không truyền range/date → lấy toàn bộ (không giới hạn thời gian).<br>
     * <p>
     * <b>Các param filter động (độc lập, có thể kết hợp):</b><br>
     * - {@code walletId}    — Giao dịch thuộc ví.<br>
     * - {@code savingGoalId}— Giao dịch thuộc mục tiêu tiết kiệm.<br>
     * - {@code eventId}     — Tất cả giao dịch thuộc sự kiện.<br>
     * - {@code debtId}      — Chỉ giao dịch nằm trong sổ nợ này.<br>
     * - {@code plannedId}   — Giao dịch thuộc hóa đơn (Bill). Trả rỗng nếu là Recurring.<br>
     * - {@code categoryIds} — Giao dịch thuộc danh mục (có thể truyền multiple: {@code ?categoryIds=21,22}).<br>
     * <p>
     * <b>Hỗ trợ multiple categoryIds:</b><br>
     * Cách 1: {@code ?categoryIds=21,22} (comma-separated)<br>
     * Cách 2: {@code ?categoryIds=21&categoryIds=22} (repeat param)<br>
     * <p>
     * Trả về: tổng thu, tổng chi, số ròng, số lượng và danh sách gom nhóm theo ngày.
     */
    @GetMapping("/list")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<TransactionListResponse>> getTransactionList(
            @RequestParam(value = "startDate",    required = false) LocalDateTime startDate,
            @RequestParam(value = "endDate",      required = false) LocalDateTime endDate,
            @RequestParam(value = "range",        required = false) DateRange range,
            @RequestParam(value = "walletId",     required = false) Integer walletId,
            @RequestParam(value = "savingGoalId", required = false) Integer savingGoalId,
            @RequestParam(value = "eventId",      required = false) Integer eventId,
            @RequestParam(value = "debtId",       required = false) Integer debtId,
            @RequestParam(value = "plannedId",    required = false) Integer plannedId,
            @RequestParam(value = "categoryIds",  required = false) List<Integer> categoryIds,
            @AuthenticationPrincipal Account currentUser) {

        // Nếu có range hoặc date → resolve; không có → null (không lọc theo thời gian)
        LocalDateTime resolvedStart = null;
        LocalDateTime resolvedEnd   = null;
        if (range != null || startDate != null || endDate != null) {
            LocalDateTime[] dates = DateUtils.resolveDateRange(startDate, endDate, range);
            resolvedStart = dates[0];
            resolvedEnd   = dates[1];
        }

        Integer userId = currentUser.getId();
        TransactionListResponse result = transactionService.getTransactionList(
                userId, resolvedStart, resolvedEnd,
                walletId, savingGoalId,
                eventId, debtId, plannedId, categoryIds);
        return ResponseEntity.ok(ApiResponse.success(result));
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