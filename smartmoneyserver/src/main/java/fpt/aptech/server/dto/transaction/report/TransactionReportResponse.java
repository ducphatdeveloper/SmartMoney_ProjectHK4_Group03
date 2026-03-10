package fpt.aptech.server.dto.transaction.report;

import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.List;

/**
 * DTO trả về dữ liệu tổng quan cho màn hình "Báo cáo" (Tab Báo cáo).
 * Bao gồm:
 * 1. Phần Header: Tổng quan tài chính (Vào/Ra/Ròng) + Số dư đầu/cuối kỳ.
 * 2. Phần Thống kê: Số lượng giao dịch Nợ/Cho vay.
 */
@Builder
public record TransactionReportResponse(
    // --- Số dư ---
    BigDecimal openingBalance, // Số dư đầu kỳ
    BigDecimal closingBalance, // Số dư cuối kỳ

    // --- Tổng quan trong kỳ ---
    BigDecimal totalIncome,  // Tổng tiền thu vào
    BigDecimal totalExpense, // Tổng tiền chi ra
    BigDecimal netIncome,    // Thu nhập ròng (Thu - Chi)

    // --- Thống kê số lượng giao dịch ---
    int debtTransactionCount, // Số lượng giao dịch liên quan đến Nợ (Đi vay, Trả nợ)
    int loanTransactionCount, // Số lượng giao dịch liên quan đến Cho vay (Cho vay, Thu nợ)

    // --- Danh sách giao dịch ---
    // Có thể null nếu chỉ gọi API lấy Summary
    List<TransactionResponse> transactions
) {}