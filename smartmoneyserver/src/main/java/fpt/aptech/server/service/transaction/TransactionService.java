package fpt.aptech.server.service.transaction;

import fpt.aptech.server.dto.transaction.report.DailyTrendDTO;
import fpt.aptech.server.dto.transaction.report.FinancialReportResponse;
import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.report.TransactionReportResponse;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.request.TransactionSearchRequest;
import fpt.aptech.server.dto.transaction.view.CategoryTransactionGroup;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;

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
}