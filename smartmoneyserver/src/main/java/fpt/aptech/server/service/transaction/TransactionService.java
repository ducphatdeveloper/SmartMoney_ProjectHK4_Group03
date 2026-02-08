package fpt.aptech.server.service.transaction;

import fpt.aptech.server.dto.transaction.TransactionRequest;
import fpt.aptech.server.dto.transaction.TransactionResponse;

import java.util.List;

public interface TransactionService {

    /**
     * Tạo một giao dịch mới.
     */
    TransactionResponse createTransaction(TransactionRequest request, Integer accountId);

    /**
     * Lấy danh sách tất cả giao dịch của người dùng hiện tại.
     */
    List<TransactionResponse> getTransactionsByCurrentUser(Integer accountId);

    /**
     * Lấy thông tin chi tiết của một giao dịch theo ID.
     */
    TransactionResponse getTransactionById(Integer transactionId, Integer accountId);

    /**
     * Cập nhật thông tin của một giao dịch đã tồn tại.
     */
    TransactionResponse updateTransaction(Integer transactionId, TransactionRequest request, Integer accountId);

    /**
     * Xóa (mềm) một giao dịch.
     */
    void deleteTransaction(Integer transactionId, Integer accountId);
}
