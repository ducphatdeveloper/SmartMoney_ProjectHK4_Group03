package fpt.aptech.server.service.transaction;

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
import fpt.aptech.server.entity.Transaction;

import java.time.LocalDateTime;
import java.util.List;

public interface TransactionService {

    // ================= 1. TẠO MỚI (CREATE) =================
    TransactionResponse createTransaction(TransactionRequest request, Integer accountId);

    // ================= 2. XEM & CHI TIẾT (READ) =================
    List<DailyTransactionGroup> getJournalTransactions(
            Integer accountId,
            LocalDateTime startDate,
            LocalDateTime endDate,
            Integer walletId,
            Integer savingGoalId
    );

    List<CategoryTransactionGroup> getGroupedTransactions(
            Integer accountId,
            LocalDateTime startDate,
            LocalDateTime endDate,
            Integer walletId,
            Integer savingGoalId
    );

    TransactionResponse getTransactionById(Long transactionId, Integer accountId);

    // ================= 3. TÌM KIẾM & BÁO CÁO (SEARCH & REPORT) =================
    List<TransactionResponse> searchTransactions(Integer accountId, TransactionSearchRequest request);

    /**
     * [3.X] Lấy danh sách giao dịch dùng chung với filter động.
     * Hỗ trợ: eventId, debtId, plannedId (Bill only), categoryIds (support multiple).
     * Trả về TransactionListResponse (tổng thu/chi + gom nhóm theo ngày).
     */
    TransactionListResponse getTransactionList(
            Integer accountId,
            LocalDateTime startDate,
            LocalDateTime endDate,
            Integer walletId,
            Integer savingGoalId,
            Integer eventId,
            Integer debtId,
            Integer plannedId,
            List<Integer> categoryIds
    );

    TransactionReportResponse getTransactionReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId);

    List<CategoryReportDTO> getCategoryReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId);

    FinancialReportResponse getFinancialReport(Integer accountId, LocalDateTime startDate, LocalDateTime endDate, Integer walletId, Integer savingGoalId);

    List<DailyTrendDTO> getDailyTrend(
            Integer accountId,
            LocalDateTime startDate,
            LocalDateTime endDate,
            Integer walletId,
            Integer savingGoalId,
            Integer categoryId
    );

    // ================= 4. CẬP NHẬT & XÓA (UPDATE & DELETE) =================
    TransactionResponse updateTransaction(Long transactionId, TransactionRequest request, Integer accountId);

    void deleteTransaction(Long transactionId, Integer accountId);

    // ================= 5. HỖ TRỢ HÀM (HELPER) =================
    // [HELPER] Hoàn tiền về ví khi xóa hoặc gộp giao dịch ( chỉ hoạt động với ít giao dịch )

    void revertTransactionBalance(Transaction transaction);
    // [HELPER] Hoàn tiền hàng loạt bằng Native SQL khi xóa Category
    void revertAllTransactionBalancesForCategoryNoFetch(Integer categoryId, Integer accountId);
}